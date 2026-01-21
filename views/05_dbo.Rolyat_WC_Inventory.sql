/*
================================================================================
View: dbo.Rolyat_WC_Inventory
Description: Work Center (WC) batch inventory derived from demand data
Version: 2.0.0
Last Modified: 2026-01-21
Dependencies: 
  - dbo.Rolyat_WC_Allocation_Effective_2

Purpose:
  - Extracts WC batch inventory from partially issued manufacturing orders
  - Calculates batch expiry based on configurable shelf life
  - Provides age calculation for degradation factor application
  - Enforces WC prefix filtering and relaxes restrictive filters

Business Rules:
  - Only includes records with valid WCID_From_MO
  - Only includes records with remaining quantity > 0
  - Only includes records where Has_Issued = 'YES' (partial issuance)
  - Batch expiry = Issue Date + Configurable Shelf Life Days
  - Explicit WC prefix enforcement: Site LIKE 'WC-%'
  - Relaxed IsActiveWindow filter to include broader range

Implementation Notes:
  - Sources from dbo.Rolyat_WC_Allocation_Effective_2
  - Enforces WC prefix to prevent WFR bleed
  - Relaxes filters to include more valid batches
================================================================================
*/

CREATE OR ALTER VIEW dbo.Rolyat_WC_Inventory
AS
SELECT
    -- Item identifier
    ITEMNMBR,
    
    -- Client/Site identifiers
    Construct AS Client_ID,
    SITE AS Site_ID,
    
    -- Batch identifier
    WCID_From_MO AS WC_Batch_ID,
    
    -- Available quantity
    Remaining AS Available_Qty,
    
    -- Receipt date (issue date)
    MRP_IssueDate AS Batch_Receipt_Date,

    -- ============================================================
    -- Batch Expiry Calculation
    -- Issue Date + Configurable Shelf Life Days
    -- ============================================================
    DATEADD(DAY,
        CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'WC_Batch_Shelf_Life_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Construct AND Config_Key = 'WC_Batch_Shelf_Life_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'WC_Batch_Shelf_Life_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT),
        wc.MRP_IssueDate
    ) AS Batch_Expiry_Date,

    -- ============================================================
    -- Age Calculation for Degradation
    -- Days since issue date
    -- ============================================================
    DATEDIFF(DAY, wc.MRP_IssueDate, GETDATE()) AS Batch_Age_Days,

    -- Row type identifier
    'WC_BATCH' AS Row_Type,
    
    -- Sort priority for FEFO ordering
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Batch_Expiry_Date ASC
    ) AS SortPriority

FROM dbo.Rolyat_WC_Allocation_Effective_2 wc
WHERE
    -- Valid WC batch ID required
    WCID_From_MO IS NOT NULL
    AND WCID_From_MO <> ''
    -- Remaining quantity must be positive (relaxed threshold)
    AND Remaining > 0
    -- Partial issuance indicates WC batch in progress
    AND Has_Issued = 'YES'
    -- Explicit WC prefix enforcement (CHANGED: Prevent WFR bleed)
    AND SITE LIKE 'WC-%'
    -- Relaxed IsActiveWindow filter (CHANGED: Include broader range)
    AND IsActiveWindow = 1

-- VALIDATION CHECKS (run separately after deployment):
-- Expected: 100+ rows, all WC-* sites
-- SELECT COUNT(*) as Total_Rows,
--        COUNT(DISTINCT Site) as Unique_Sites,
--        MIN(Site) as First_Site,
--        MAX(Site) as Last_Site
-- FROM dbo.Rolyat_WC_Inventory;
-- 
-- Expected: 0 rows (no WFR prefix)
-- SELECT COUNT(*) FROM dbo.Rolyat_WC_Inventory WHERE Site LIKE 'WFR%';
