CREATE VIEW dbo.Rolyat_Final_Ledger_3
AS
WITH Supply_Events AS (
    -- Aggregate PO supply per item/site for Forecast (all POs)
    SELECT
        ITEMNMBR,
        Site_ID,
        SUM(PO_Qty) AS Total_PO_Supply,
        SUM(CASE WHEN Is_Released = 1 AND Is_Fully_Received = 0 THEN Open_PO_Qty ELSE 0 END) AS Released_PO_Supply
    FROM dbo.Rolyat_PO_Detail
    GROUP BY ITEMNMBR, Site_ID
),

WFQ_Aggregate AS (
    -- Aggregate WFQ/RMQTY per item/site
    SELECT
        ITEMNMBR,
        Site_ID,
        SUM(CASE WHEN Inventory_Type = 'WFQ' THEN QTY_ON_HAND ELSE 0 END) AS Total_WFQ,
        SUM(CASE WHEN Inventory_Type = 'RMQTY' AND Is_Eligible_For_Release = 1 THEN QTY_ON_HAND ELSE 0 END) AS Eligible_RMQTY
    FROM dbo.Rolyat_WFQ_5
    GROUP BY ITEMNMBR, Site_ID
),

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

SELECT
    *,

    -- Forecast Running Balance (optimistic - includes all hope sources, unsuppressed demand)
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

    -- ATP Running Balance (conservative - only released/eligible supply, suppressed demand, client-partitioned)
    SUM(
        BEG_BAL
        + Released_PO_Supply
        + Eligible_RMQTY
        -- Explicitly EXCLUDE Total_WFQ (quarantine not usable in ATP)
        - effective_demand  -- WC-SUPPRESSED demand
    ) OVER (
        PARTITION BY ITEMNMBR, Client_ID  -- Client-partitioned for segregation
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ATP_Running_Balance,

    -- Legacy adjusted balance for backward compatibility (matches ATP logic)
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

    -- QC/Status flags
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

    CASE
        WHEN IsActiveWindow = 1 AND effective_demand < Base_Demand
        THEN 1
        ELSE 0
    END AS WC_Allocation_Applied_Flag

FROM Ledger_Base

GO
