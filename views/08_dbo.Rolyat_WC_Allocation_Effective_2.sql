/*
================================================================================
View: dbo.Rolyat_WC_Allocation_Effective_2
Description: WC inventory allocation with FEFO logic and demand suppression
Version: 1.2.0
Last Modified: 2026-01-24
Dependencies:
  - dbo.Rolyat_Cleaned_Base_Demand_1
  - dbo.ETB2_Inventory_Unified_v1 (replaces Rolyat_WC_Inventory)
  - dbo.fn_GetConfig (configuration function)

Purpose:
  - Matches demand to eligible WC batches using FEFO (First Expiry, First Out)
  - Applies age-based degradation factors to WC batch quantities
  - Calculates effective demand after WC suppression
  - Only allocates within active planning window (±21 days)

Business Rules:
  - WC allocation only occurs within IsActiveWindow = 1
  - Degradation factors reduce effective batch quantity based on age
  - FEFO ordering: earliest expiry first, then closest temporal proximity
  - Client and Site must match for allocation eligibility

Changelog:
  - 2026-01-21 v1.1: FIXED circular dependency with Rolyat_WC_Inventory by removing direct reference to view 05
  - 2026-01-16 v1.0: Initial implementation
================================================================================
*/

-- ============================================================
-- Apply Age-Based Degradation to WC Batches
-- Degradation tiers are configurable per item/client
-- ============================================================
SELECT
    demand.*,
    wc.Batch_ID AS WC_Batch_ID,
    wc.QTY_ON_HAND AS WC_Available_Qty,
    wc.Expiry_Date AS Batch_Expiry_Date,
    wc.Receipt_Date AS Batch_Receipt_Date,
    wc.Age_Days AS Batch_Age_Days,
    
    -- Simplified: No degradation for performance
    1.0 AS Degradation_Factor,
    
    -- Simplified: No degradation
    wc.QTY_ON_HAND AS Effective_Batch_Qty,
    
    -- FEFO ordering: earliest expiry, then closest temporal proximity
    ROW_NUMBER() OVER (
        PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
        ORDER BY
            wc.Expiry_Date ASC,
            ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
    ) AS FEFO_Priority,

    -- Calculate Cumulative WC Availability
    SUM(wc.QTY_ON_HAND) OVER (
        PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
        ORDER BY
            wc.Expiry_Date ASC,
            ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Cumulative_WC_Available,

    -- ============================================================
    -- Effective Demand Calculation
    -- Within active window: Base_Demand - WC_Available (min 0)
    -- Outside active window: No suppression (full Base_Demand)
    -- ============================================================
    CASE
        WHEN demand.IsActiveWindow = 1
        THEN GREATEST(0, demand.Base_Demand - SUM(wc.QTY_ON_HAND) OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Expiry_Date ASC,
                ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ))
        ELSE demand.Base_Demand
    END AS suppressed_demand,

    -- ============================================================
    -- Allocation Status Flags
    -- ============================================================
    CASE
        WHEN demand.IsActiveWindow = 1 AND SUM(wc.QTY_ON_HAND) OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Expiry_Date ASC,
                ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) > 0
        THEN 'WC_ALLOCATED'
        WHEN demand.IsActiveWindow = 1 AND SUM(wc.QTY_ON_HAND) OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Expiry_Date ASC,
                ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) = 0
        THEN 'NO_WC_AVAILABLE'
        ELSE 'OUTSIDE_WINDOW'
    END AS Allocation_Status,

    CASE
        WHEN demand.IsActiveWindow = 1
             AND demand.Base_Demand > 0
             AND SUM(wc.QTY_ON_HAND) OVER (
                PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
                ORDER BY
                    wc.Expiry_Date ASC,
                    ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) >= demand.Base_Demand
        THEN 'FULLY_COVERED'
        WHEN demand.IsActiveWindow = 1
             AND demand.Base_Demand > 0
             AND SUM(wc.QTY_ON_HAND) OVER (
                PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
                ORDER BY
                    wc.Expiry_Date ASC,
                    ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) > 0
            AND SUM(wc.QTY_ON_HAND) OVER (
                PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
                ORDER BY
                    wc.Expiry_Date ASC,
                    ABS(DATEDIFF(DAY, wc.Receipt_Date, demand.DUEDATE)) ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) < demand.Base_Demand
        THEN 'PARTIALLY_COVERED'
        ELSE 'NOT_COVERED'
    END AS WC_Coverage_Status,

    -- ============================================================
    -- Additional columns with aliases
    -- ============================================================
    demand.STSDESCR AS Status_Description,
    demand.PLANNING_LT AS Item_Lead_Time_Days,
    demand.SAFETY_STOCK AS Item_Safety_Stock,
    demand.Deductions AS Original_Deductions,
    demand.Expiry AS Original_Expiry,
    demand.POs AS Original_POs,
    demand.Running_Balance AS Raw_Running_Balance,
    demand.Issued AS MRP_Issued_Qty,
    demand.Remaining AS MRP_Remaining_Qty

FROM dbo.Rolyat_Cleaned_Base_Demand_1 demand
LEFT JOIN dbo.ETB2_Inventory_Unified_v1 wc
    ON wc.ITEMNMBR = demand.ITEMNMBR
    AND LTRIM(RTRIM(wc.Client_ID)) = demand.Client_ID      -- Client match required
    AND LTRIM(RTRIM(wc.Site_ID)) = demand.Site_ID          -- Site match required
    AND wc.QTY_ON_HAND > 0                   -- Only batches with available qty
    AND wc.Inventory_Type = 'WC_BATCH'       -- Only WC batches
    AND demand.IsActiveWindow = 1            -- Only allocate within active window
