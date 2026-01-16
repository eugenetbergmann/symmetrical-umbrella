/*
================================================================================
View: dbo.Rolyat_Final_Ledger_3
Description: Final ledger with running balances, supply aggregation, and QC flags
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.Rolyat_WC_Allocation_Effective_2
  - dbo.Rolyat_PO_Detail
  - dbo.Rolyat_WFQ_5

Purpose:
  - Aggregates supply events (POs, WFQ, RMQTY) per item/site
  - Calculates Forecast Running Balance (optimistic - all hope sources)
  - Calculates ATP Running Balance (conservative - released/eligible only)
  - Provides QC flags for stock-out and deficit detection

Business Rules:
  - Forecast includes all POs, WFQ, and RMQTY
  - ATP excludes WFQ (quarantine) and unreleased POs
  - ATP is client-partitioned for inventory segregation
  - Stock_Out_Flag triggers when ATP balance goes negative
================================================================================
*/

CREATE VIEW dbo.Rolyat_Final_Ledger_3
AS

-- ============================================================
-- CTE 1: Aggregate PO Supply per Item/Site
-- Separates total PO supply from released-only supply
-- ============================================================
WITH Supply_Events AS (
    SELECT
        ITEMNMBR,
        Site_ID,
        -- Total PO supply (for Forecast)
        SUM(PO_Qty) AS Total_PO_Supply,
        -- Released PO supply only (for ATP)
        SUM(
            CASE 
                WHEN Is_Released = 1 AND Is_Fully_Received = 0 
                THEN Open_PO_Qty 
                ELSE 0 
            END
        ) AS Released_PO_Supply
    FROM dbo.Rolyat_PO_Detail
    GROUP BY ITEMNMBR, Site_ID
),

-- ============================================================
-- CTE 2: Aggregate WFQ/RMQTY per Item/Site
-- Separates total WFQ from eligible RMQTY
-- ============================================================
WFQ_Aggregate AS (
    SELECT
        ITEMNMBR,
        Site_ID,
        -- Total WFQ (quarantine - for Forecast only)
        SUM(
            CASE 
                WHEN Inventory_Type = 'WFQ' 
                THEN QTY_ON_HAND 
                ELSE 0 
            END
        ) AS Total_WFQ,
        -- Eligible RMQTY (for both Forecast and ATP)
        SUM(
            CASE 
                WHEN Inventory_Type = 'RMQTY' AND Is_Eligible_For_Release = 1 
                THEN QTY_ON_HAND 
                ELSE 0 
            END
        ) AS Eligible_RMQTY
    FROM dbo.Rolyat_WFQ_5
    GROUP BY ITEMNMBR, Site_ID
),

-- ============================================================
-- CTE 3: Join Demand with Supply Aggregates
-- ============================================================
Ledger_Base AS (
    SELECT
        demand.*,
        COALESCE(supply.Total_PO_Supply, 0) AS Total_PO_Supply,
        COALESCE(supply.Released_PO_Supply, 0) AS Released_PO_Supply,
        COALESCE(wfq.Total_WFQ, 0) AS Total_WFQ,
        COALESCE(wfq.Eligible_RMQTY, 0) AS Eligible_RMQTY
    FROM dbo.Rolyat_WC_Allocation_Effective_2 demand
    LEFT JOIN Supply_Events supply
        ON supply.ITEMNMBR = demand.ITEMNMBR
        AND supply.Site_ID = demand.Site_ID
    LEFT JOIN WFQ_Aggregate wfq
        ON wfq.ITEMNMBR = demand.ITEMNMBR
        AND wfq.Site_ID = demand.Site_ID
)

-- ============================================================
-- Final SELECT with Running Balance Calculations
-- ============================================================
SELECT
    *,

    -- ============================================================
    -- Forecast Running Balance (Optimistic)
    -- Includes: BEG_BAL + All POs + WFQ + RMQTY - Base_Demand
    -- Partitioned by ITEMNMBR only (global view)
    -- ============================================================
    SUM(
        BEG_BAL
        + Total_PO_Supply
        + Total_WFQ
        + Eligible_RMQTY
        - Base_Demand  -- UNSUPPRESSED full requirement
    ) OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Forecast_Running_Balance,

    -- ============================================================
    -- ATP Running Balance (Conservative)
    -- Includes: BEG_BAL + Released POs + RMQTY - effective_demand
    -- Excludes: WFQ (quarantine not usable in ATP)
    -- Partitioned by ITEMNMBR + Client_ID (segregated view)
    -- ============================================================
    SUM(
        BEG_BAL
        + Released_PO_Supply
        + Eligible_RMQTY
        - effective_demand  -- WC-SUPPRESSED demand
    ) OVER (
        PARTITION BY ITEMNMBR, Client_ID
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ATP_Running_Balance,

    -- ============================================================
    -- Legacy Adjusted Balance (matches ATP logic)
    -- Retained for backward compatibility
    -- ============================================================
    SUM(
        BEG_BAL
        + Released_PO_Supply
        + Eligible_RMQTY
        - effective_demand
    ) OVER (
        PARTITION BY ITEMNMBR, Client_ID
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Adjusted_Running_Balance,

    -- ============================================================
    -- QC/Status Flags
    -- ============================================================
    
    -- Stock_Out_Flag: ATP balance goes negative
    CASE
        WHEN SUM(
            BEG_BAL + Released_PO_Supply + Eligible_RMQTY - effective_demand
        ) OVER (
            PARTITION BY ITEMNMBR, Client_ID
            ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) < 0
        THEN 1
        ELSE 0
    END AS Stock_Out_Flag,

    -- Potential_Deficit_Flag: Forecast balance goes negative
    CASE
        WHEN SUM(
            BEG_BAL + Total_PO_Supply + Total_WFQ + Eligible_RMQTY - Base_Demand
        ) OVER (
            PARTITION BY ITEMNMBR
            ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) < 0
        THEN 1
        ELSE 0
    END AS Potential_Deficit_Flag,

    -- WC_Allocation_Applied_Flag: Demand was suppressed by WC allocation
    CASE
        WHEN IsActiveWindow = 1 AND effective_demand < Base_Demand
        THEN 1
        ELSE 0
    END AS WC_Allocation_Applied_Flag

FROM Ledger_Base

GO

-- Add extended property for documentation
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Final ledger view with Forecast (optimistic) and ATP (conservative) running balances, supply aggregation, and QC flags for stock-out detection.',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'VIEW', @level1name = 'Rolyat_Final_Ledger_3'
GO
