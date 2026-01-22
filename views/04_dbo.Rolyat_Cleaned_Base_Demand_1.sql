/*
================================================================================
View: dbo.Rolyat_Cleaned_Base_Demand_1
Description: Data cleansing and base demand calculation from ETB_PAB_AUTO
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: dbo.ETB_PAB_AUTO

Purpose:
  - Standardizes and cleanses raw demand data from ETB_PAB_AUTO
  - Calculates Base_Demand using priority logic (Remaining > Deductions > Expiry)
  - Assigns deterministic SortPriority for event ordering
  - Flags records within active planning window (±21 days)

Business Rules:
  - Excludes items with prefixes 60.x and 70.x
  - Excludes partially received orders
  - Excludes records with invalid dates
  - Active window: ±21 days from current date
================================================================================
*/

CREATE OR ALTER VIEW dbo.Rolyat_Cleaned_Base_Demand_1
AS
SELECT
    -- ============================================================
    -- Order Identifiers (cleaned and standardized)
    -- ============================================================
    UPPER(TRIM(ORDERNUMBER)) AS ORDERNUMBER,
    UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        TRIM(REPLACE(ORDERNUMBER, 'MO', '')),
        '-', ''), ' ', ''), '/', ''), '.', ''), '#', '')) AS CleanOrder,

    -- ============================================================
    -- Item Identifiers
    -- ============================================================
    TRIM(ITEMNMBR) AS ITEMNMBR,
    TRIM(ITEMNMBR) AS CleanItem,  -- Retained for backward compatibility

    -- ============================================================
    -- Work Center and Product Hierarchy
    -- ============================================================
    TRIM(COALESCE(WCID_From_MO, '')) AS WCID_From_MO,
    TRIM(COALESCE(Construct, '')) AS Construct,
    TRIM(COALESCE(Construct, '')) AS Client_ID,
    TRIM(COALESCE(FG, '')) AS FG,
    TRIM(COALESCE([FG Desc], '')) AS FG_Desc,
    TRIM(COALESCE(ItemDescription, '')) AS ItemDescription,

    -- ============================================================
    -- Item Attributes
    -- ============================================================
    TRIM(COALESCE(UOMSCHDL, '')) AS UOMSCHDL,
    TRIM(COALESCE(STSDESCR, '')) AS STSDESCR,
    TRIM(COALESCE(MRPTYPE, '')) AS MRPTYPE,
    TRIM(COALESCE(VendorItem, '')) AS VendorItem,
    TRIM(COALESCE(INCLUDE_MRP, '')) AS INCLUDE_MRP,
    TRIM(COALESCE(SITE, '')) AS SITE,
    TRIM(COALESCE(SITE, '')) AS Site_ID,
    TRIM(COALESCE(PRIME_VNDR, '')) AS PRIME_VNDR,

    -- ============================================================
    -- Date Fields (converted to DATE type with validation)
    -- ============================================================
    TRY_CONVERT(DATE, [Date + Expiry]) AS Date_Expiry,
    TRY_CONVERT(DATE, [Expiry Dates]) AS Expiry_Dates,
    TRY_CONVERT(DATE, DUEDATE) AS DUEDATE,
    TRY_CONVERT(DATE, MRP_IssueDate) AS MRP_IssueDate,

    -- ============================================================
    -- Quantity Fields (converted to DECIMAL with NULL protection)
    -- ============================================================
    COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) AS BEG_BAL,
    COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS POs,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS Deductions,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS CleanDeductions,
    COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) AS Expiry,
    COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) AS Remaining,
    COALESCE(TRY_CAST(Running_Balance AS DECIMAL(18, 5)), 0.0) AS Running_Balance,
    COALESCE(TRY_CAST(Issued AS DECIMAL(18, 5)), 0.0) AS Issued,

    -- ============================================================
    -- Planning Parameters
    -- ============================================================
    COALESCE(TRY_CAST(PURCHASING_LT AS DECIMAL(18, 5)), 0.0) AS PURCHASING_LT,
    COALESCE(TRY_CAST(PLANNING_LT AS DECIMAL(18, 5)), 0.0) AS PLANNING_LT,
    COALESCE(TRY_CAST(ORDER_POINT_QTY AS DECIMAL(18, 5)), 0.0) AS ORDER_POINT_QTY,
    COALESCE(TRY_CAST(SAFETY_STOCK AS DECIMAL(18, 5)), 0.0) AS SAFETY_STOCK,

    -- ============================================================
    -- Status Flags (standardized to uppercase YES/NO)
    -- ============================================================
    UPPER(TRIM(COALESCE(Has_Issued, 'NO'))) AS Has_Issued,
    UPPER(TRIM(COALESCE(IssueDate_Mismatch, 'NO'))) AS IssueDate_Mismatch,
    UPPER(TRIM(COALESCE(Early_Issue_Flag, 'NO'))) AS Early_Issue_Flag,

    -- ============================================================
    -- Base_Demand Calculation
    -- Priority Logic:
    --   1. If Remaining > 0, use Remaining
    --   2. Else if Deductions > 0, use Deductions
    --   3. Else if Expiry > 0, use Expiry
    --   4. Otherwise, 0.0
    -- ============================================================
    CASE
        WHEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) > 0 
            THEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0)
        WHEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) > 0 
            THEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0)
        WHEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) > 0 
            THEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0)
        ELSE 0.0
    END AS Base_Demand,

    -- ============================================================
    -- SortPriority for Deterministic Event Ordering
    -- Lower value = higher priority in processing sequence
    -- Priority: Beginning Balance (1) > POs (2) > Demand (3) > Expiry (4)
    -- ============================================================
    CASE
        WHEN COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) > 0 THEN 1
        WHEN COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) > 0 THEN 2
        WHEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) > 0 
             OR COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) > 0 THEN 3
        WHEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) > 0 THEN 4
        ELSE 5
    END AS SortPriority,

    -- ============================================================
    -- IsActiveWindow Flag
    -- Identifies records within configurable planning window
    -- Used for WC allocation gating
    -- ============================================================
    CASE
        WHEN TRY_CONVERT(DATE, DUEDATE) BETWEEN DATEADD(DAY,
             -CAST(COALESCE((SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'ActiveWindow_Past_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())), NULL) AS INT),
             GETDATE())
             AND DATEADD(DAY,
             CAST(COALESCE((SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'ActiveWindow_Future_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())), NULL) AS INT),
             GETDATE()) THEN 1
        ELSE 0
    END AS IsActiveWindow

FROM dbo.ETB_PAB_AUTO
WHERE
    -- Exclude rows with invalid dates
    TRY_CONVERT(DATE, [Date + Expiry]) IS NOT NULL
    -- Exclude specific item prefixes (60.x and 70.x series)
    AND TRIM(ITEMNMBR) NOT LIKE '60.%'
    AND TRIM(ITEMNMBR) NOT LIKE '70.%'
    -- Exclude partially received orders
    AND TRIM(COALESCE(STSDESCR, '')) <> 'Partially Received'

/*
Diagnostic queries for Task 1: Diagnose Upstream PAB Auto → Cleaned_Base_Demand_1 PO Flow
-- Check PO events in upstream cleansing
SELECT TOP 20 * FROM Rolyat_Cleaned_Base_Demand_1 WHERE SortPriority = 2 ORDER BY DUEDATE DESC;
-- Sample running balance impact from POs
SELECT ITEMNMBR AS Item, Base_Demand, SortPriority FROM Rolyat_Cleaned_Base_Demand_1 WHERE SortPriority = 2;
-- Raw PAB Auto PO source sample (adjusted to ETB_PAB_AUTO)
SELECT TOP 20 ORDERNUMBER, ITEMNMBR, [PO's] AS Qty, DUEDATE AS DueDate FROM dbo.ETB_PAB_AUTO WHERE STSDESCR <> 'Partially Received';
*/
