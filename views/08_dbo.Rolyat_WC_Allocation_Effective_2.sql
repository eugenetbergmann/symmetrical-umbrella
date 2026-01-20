/*
================================================================================
View: dbo.Rolyat_WC_Allocation_Effective_2
Description: WC inventory allocation with FEFO logic and demand suppression
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.Rolyat_Cleaned_Base_Demand_1
  - dbo.Rolyat_WC_Inventory
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
================================================================================
*/

-- ============================================================
-- Apply Age-Based Degradation to WC Batches
-- Degradation tiers are configurable per item/client
-- ============================================================
SELECT
    demand.*,
    wc.WC_Batch_ID,
    wc.Available_Qty AS WC_Available_Qty,
    wc.Batch_Expiry_Date,
    wc.Batch_Receipt_Date,
    wc.Batch_Age_Days,
    
    -- Calculate degradation factor based on configurable age tiers
    CASE
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        ELSE CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS DECIMAL(5,2))
    END AS Degradation_Factor,
    
    -- Calculate Effective Quantity After Degradation
    wc.Available_Qty * CASE
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        ELSE CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS DECIMAL(5,2))
    END AS Effective_Batch_Qty,
    
    -- FEFO ordering: earliest expiry, then closest temporal proximity
    ROW_NUMBER() OVER (
        PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
        ORDER BY
            wc.Batch_Expiry_Date ASC,
            ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
    ) AS FEFO_Priority,

    -- Calculate Cumulative WC Availability
    SUM(wc.Available_Qty * CASE
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        WHEN wc.Batch_Age_Days <= CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT)
            THEN CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        ELSE CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS DECIMAL(5,2))
    END) OVER (
        PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
        ORDER BY
            wc.Batch_Expiry_Date ASC,
            ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Cumulative_WC_Available,

    -- ============================================================
    -- Effective Demand Calculation
    -- Within active window: Base_Demand - WC_Available (min 0)
    -- Outside active window: No suppression (full Base_Demand)
    -- ============================================================
    CASE
        WHEN demand.IsActiveWindow = 1
        THEN GREATEST(0, demand.Base_Demand - SUM(wc.Available_Qty * CASE
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            ELSE CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        END) OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Batch_Expiry_Date ASC,
                ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ))
        ELSE demand.Base_Demand
    END AS effective_demand,

    -- ============================================================
    -- Allocation Status Flags
    -- ============================================================
    CASE
        WHEN demand.IsActiveWindow = 1 AND SUM(wc.Available_Qty * CASE
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            ELSE CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        END) OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Batch_Expiry_Date ASC,
                ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) > 0
        THEN 'WC_ALLOCATED'
        WHEN demand.IsActiveWindow = 1 AND SUM(wc.Available_Qty * CASE
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT)
                THEN CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            ELSE CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS DECIMAL(5,2))
        END) OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Batch_Expiry_Date ASC,
                ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) = 0
        THEN 'NO_WC_AVAILABLE'
        ELSE 'OUTSIDE_WINDOW'
    END AS Allocation_Status,

    CASE
        WHEN demand.IsActiveWindow = 1
             AND demand.Base_Demand > 0
             AND SUM(wc.Available_Qty * CASE
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                ELSE CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            END) OVER (
                PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
                ORDER BY
                    wc.Batch_Expiry_Date ASC,
                    ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) >= demand.Base_Demand
        THEN 'FULLY_COVERED'
        WHEN demand.IsActiveWindow = 1
             AND demand.Base_Demand > 0
             AND SUM(wc.Available_Qty * CASE
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                ELSE CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            END) OVER (
                PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
                ORDER BY
                    wc.Batch_Expiry_Date ASC,
                    ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) > 0
            AND SUM(wc.Available_Qty * CASE
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier1_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier2_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                WHEN wc.Batch_Age_Days <= CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS INT)
                    THEN CAST(COALESCE(
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier3_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                    ) AS DECIMAL(5,2))
                ELSE CAST(COALESCE(
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Client_ID AND Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                    (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Degradation_Tier4_Factor' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                ) AS DECIMAL(5,2))
            END) OVER (
                PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
                ORDER BY
                    wc.Batch_Expiry_Date ASC,
                    ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
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
    demand.Running_Balance AS Original_Running_Balance,
    demand.Issued AS MRP_Issued_Qty,
    demand.Remaining AS MRP_Remaining_Qty

FROM dbo.Rolyat_Cleaned_Base_Demand_1 demand
LEFT JOIN dbo.Rolyat_WC_Inventory wc
    ON wc.ITEMNMBR = demand.ITEMNMBR
    AND wc.Client_ID = demand.Construct      -- Client match required
    AND wc.Site_ID = demand.SITE             -- Site match required
    AND wc.Available_Qty > 0                 -- Only batches with available qty
    AND demand.IsActiveWindow = 1            -- Only allocate within active window
