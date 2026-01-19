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

CREATE OR ALTER VIEW dbo.Rolyat_WC_Allocation_Effective_2
AS

-- ============================================================
-- CTE 1: Apply Age-Based Degradation to WC Batches
-- Degradation tiers are configurable per item/client
-- ============================================================
WITH WC_With_Degradation AS (
    SELECT
        wc.*,
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
        END AS Degradation_Factor
    FROM dbo.Rolyat_WC_Inventory wc
),

-- ============================================================
-- CTE 2: Calculate Effective Quantity After Degradation
-- ============================================================
WC_Effective_Qty AS (
    SELECT
        *,
        Available_Qty * Degradation_Factor AS Effective_Batch_Qty
    FROM WC_With_Degradation
),

-- ============================================================
-- CTE 3: Match Demand to Eligible WC Batches
-- Applies FEFO ordering for allocation priority
-- ============================================================
Demand_WC_Eligible AS (
    SELECT
        demand.*,
        wc.WC_Batch_ID,
        wc.Available_Qty AS WC_Available_Qty,
        wc.Batch_Expiry_Date,
        wc.Batch_Receipt_Date,
        wc.Batch_Age_Days,
        wc.Degradation_Factor,
        wc.Effective_Batch_Qty,

        -- FEFO ordering: earliest expiry, then closest temporal proximity
        ROW_NUMBER() OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Batch_Expiry_Date ASC,
                ABS(DATEDIFF(DAY, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
        ) AS FEFO_Priority

    FROM dbo.Rolyat_Cleaned_Base_Demand_1 demand
    LEFT JOIN WC_Effective_Qty wc
        ON wc.ITEMNMBR = demand.ITEMNMBR
        AND wc.Client_ID = demand.Client_ID      -- Client match required
        AND wc.Site_ID = demand.Site_ID          -- Site match required
        AND wc.Effective_Batch_Qty > 0           -- Only batches with available qty
        AND demand.IsActiveWindow = 1            -- Only allocate within active window
),

-- ============================================================
-- CTE 4: Calculate Cumulative WC Availability
-- Uses window function for running total per demand
-- ============================================================
Cumulative_WC_Allocation AS (
    SELECT
        *,
        SUM(Effective_Batch_Qty) OVER (
            PARTITION BY ITEMNMBR, ORDERNUMBER
            ORDER BY FEFO_Priority
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Cumulative_WC_Available
    FROM Demand_WC_Eligible
),

-- ============================================================
-- CTE 5: Final Allocation with Effective Demand Calculation
-- ============================================================
Final_Allocation AS (
    SELECT
        -- Primary identifiers
        ORDERNUMBER,
        ITEMNMBR,
        Client_ID,
        Site_ID,
        DUEDATE,
        Date_Expiry,
        Base_Demand,
        IsActiveWindow,
        SortPriority,
        Row_Type,

        -- WC allocation details (from first/best FEFO batch)
        WC_Batch_ID,
        Degradation_Factor,

        -- Total WC available after cumulative FEFO allocation
        MAX(Cumulative_WC_Available) AS Total_WC_Available,

        -- ============================================================
        -- Effective Demand Calculation
        -- Within active window: Base_Demand - WC_Available (min 0)
        -- Outside active window: No suppression (full Base_Demand)
        -- ============================================================
        CASE
            WHEN IsActiveWindow = 1
            THEN GREATEST(0, Base_Demand - MAX(Cumulative_WC_Available))
            ELSE Base_Demand
        END AS effective_demand,

        -- ============================================================
        -- Allocation Status Flags
        -- ============================================================
        CASE
            WHEN IsActiveWindow = 1 AND MAX(Cumulative_WC_Available) > 0
            THEN 'WC_ALLOCATED'
            WHEN IsActiveWindow = 1 AND MAX(Cumulative_WC_Available) = 0
            THEN 'NO_WC_AVAILABLE'
            ELSE 'OUTSIDE_WINDOW'
        END AS Allocation_Status,

        CASE
            WHEN IsActiveWindow = 1
                 AND Base_Demand > 0
                 AND MAX(Cumulative_WC_Available) >= Base_Demand
            THEN 'FULLY_COVERED'
            WHEN IsActiveWindow = 1
                 AND Base_Demand > 0
                 AND MAX(Cumulative_WC_Available) > 0
                 AND MAX(Cumulative_WC_Available) < Base_Demand
            THEN 'PARTIALLY_COVERED'
            ELSE 'NOT_COVERED'
        END AS WC_Coverage_Status,

        -- ============================================================
        -- Pass-through columns from demand
        -- ============================================================
        ItemDescription,
        UOMSCHDL,
        Status_Description,
        MRPTYPE,
        VendorItem,
        INCLUDE_MRP,
        BEG_BAL,
        Item_Lead_Time_Days,
        Item_Safety_Stock,
        ORDER_POINT_QTY,
        PLANNING_LT,
        PRIME_VNDR,
        Original_Deductions,
        Original_Expiry,
        Original_POs,
        Original_Running_Balance,
        MRP_IssueDate,
        WCID_From_MO,
        MRP_Issued_Qty,
        MRP_Remaining_Qty,
        Has_Issued,
        IssueDate_Mismatch,
        Early_Issue_Flag

    FROM Cumulative_WC_Allocation
    GROUP BY
        ORDERNUMBER, ITEMNMBR, Client_ID, Site_ID, DUEDATE, Date_Expiry,
        Base_Demand, IsActiveWindow, SortPriority, Row_Type,
        WC_Batch_ID, Degradation_Factor,
        ItemDescription, UOMSCHDL, Status_Description, MRPTYPE, VendorItem,
        INCLUDE_MRP, BEG_BAL, Item_Lead_Time_Days, Item_Safety_Stock,
        ORDER_POINT_QTY, PLANNING_LT, PRIME_VNDR,
        Original_Deductions, Original_Expiry, Original_POs, Original_Running_Balance,
        MRP_IssueDate, WCID_From_MO, MRP_Issued_Qty, MRP_Remaining_Qty,
        Has_Issued, IssueDate_Mismatch, Early_Issue_Flag
)

SELECT * FROM Final_Allocation
