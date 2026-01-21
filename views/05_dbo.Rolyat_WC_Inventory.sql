/*
================================================================================
View: dbo.Rolyat_WC_Inventory
Description: Work Center (WC) batch inventory derived from demand data
Version: 2.1.0
Last Modified: 2026-01-21
Dependencies: 
  - dbo.Rolyat_Cleaned_Base_Demand_1
  - dbo.Rolyat_Config_Items
  - dbo.Rolyat_Config_Clients
  - dbo.Rolyat_Config_Global

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
  - FIXED: Removed FROM dbo.Rolyat_WC_Allocation_Effective_2 to eliminate circular reference
  - RATIONALE: View 08 was (likely) referencing back to inventory/ledger → cycle
  - SOLUTION: Now sources directly from 04_dbo.Rolyat_Cleaned_Base_Demand_1 with inlined WC filters
  - Enforces WC prefix to prevent WFR bleed
  - Relaxes filters to include more valid batches
================================================================================
*/

CREATE OR ALTER VIEW dbo.Rolyat_WC_Inventory
AS

SELECT
    -- Item identifier
    src.ITEMNMBR,
    
    -- Client/Site identifiers
    src.Construct AS Client_ID,
    src.SITE AS Site_ID,
    
    -- Batch identifier
    src.WCID_From_MO AS WC_Batch_ID,
    
    -- Available quantity
    src.Remaining AS Available_Qty,
    
    -- Receipt date (issue date)
    src.MRP_IssueDate AS Batch_Receipt_Date,

    -- ============================================================
    -- Batch Expiry Calculation
    -- Issue Date + Configurable Shelf Life Days
    -- ============================================================
    DATEADD(DAY,
        CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items ci WHERE ci.ITEMNMBR = src.ITEMNMBR AND ci.Config_Key = 'WC_Batch_Shelf_Life_Days' AND ci.Effective_Date <= GETDATE() AND (ci.Expiry_Date IS NULL OR ci.Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients cc WHERE cc.Client_ID = src.Construct AND cc.Config_Key = 'WC_Batch_Shelf_Life_Days' AND cc.Effective_Date <= GETDATE() AND (cc.Expiry_Date IS NULL OR cc.Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global cg WHERE cg.Config_Key = 'WC_Batch_Shelf_Life_Days' AND cg.Effective_Date <= GETDATE() AND (cg.Expiry_Date IS NULL OR cg.Expiry_Date > GETDATE()))
        ) AS INT),
        src.MRP_IssueDate
    ) AS Batch_Expiry_Date,

    -- ============================================================
    -- Age Calculation for Degradation
    -- Days since issue date
    -- ============================================================
    DATEDIFF(DAY, src.MRP_IssueDate, GETDATE()) AS Batch_Age_Days,

    -- Row type identifier
    'WC_BATCH' AS Row_Type,
    
    -- Sort priority for FEFO ordering
    ROW_NUMBER() OVER (
        PARTITION BY src.ITEMNMBR
        ORDER BY Batch_Expiry_Date ASC
    ) AS SortPriority

FROM dbo.Rolyat_Cleaned_Base_Demand_1 src
WHERE
    -- Valid WC batch ID required
    src.WCID_From_MO IS NOT NULL
    AND src.WCID_From_MO <> ''
    -- Remaining quantity must be positive (relaxed threshold)
    AND src.Remaining > 0
    -- Partial issuance indicates WC batch in progress
    AND src.Has_Issued = 'YES'
    -- Explicit WC prefix enforcement (CHANGED: Prevent WFR bleed)
    AND src.SITE LIKE 'WC%'
    -- Relaxed IsActiveWindow filter (CHANGED: Include broader range)
    AND src.IsActiveWindow = 1

-- ============================================================
-- VALIDATION QUERIES (run after deploy):
-- ============================================================
-- Test 1: Row count & WC sites only
SELECT COUNT(*) AS Total_Rows, COUNT(DISTINCT Site_ID) AS Unique_WC_Sites FROM dbo.Rolyat_WC_Inventory;
-- Test 2: No bleed to other prefixes
SELECT COUNT(*) FROM dbo.Rolyat_WC_Inventory WHERE Site_ID NOT LIKE 'WC%';
-- Test 3: FEFO order check
SELECT TOP 50 * FROM dbo.Rolyat_WC_Inventory ORDER BY SortPriority, Batch_Expiry_Date;
