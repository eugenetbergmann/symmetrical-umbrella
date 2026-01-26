/*******************************************************************************
* View Name:    ETB2_Inventory_Unified_Eligible
* Deploy Order: 07 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Unified eligible inventory combining WC batches and excluding quarantine
* Grain:        One row per item per location (aggregated)
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05 - deploy first)
*   ✓ dbo.ETB2_Inventory_Quarantine_Restricted (view 06 - deploy first)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Inventory_Unified_Eligible
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible
*   Expected: WC inventory minus quarantine/restricted items
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    ITEMNMBR,
    Work_Center,
    SUM(Quantity) AS Eligible_Qty,
    MIN(Expiry_Date) AS Earliest_Expiry,
    COUNT(*) AS Batch_Count,
    'UNIFIED' AS Inventory_Source
FROM dbo.ETB_Inventory_WC
WHERE ITEMNMBR NOT IN (
    -- Exclude items that are in quarantine/restricted
    SELECT ITEMNMBR FROM dbo.ETB2_Inventory_Quarantine_Restricted
)
GROUP BY ITEMNMBR, Work_Center

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Row count check:
   SELECT COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible
   -- Should be less than view 05 (quarantine items excluded)

2. Location distribution:
   SELECT 
       Work_Center,
       COUNT(DISTINCT ITEMNMBR) AS Unique_Items,
       SUM(Eligible_Qty) AS Total_Qty
   FROM dbo.ETB2_Inventory_Unified_Eligible
   GROUP BY Work_Center
   ORDER BY Work_Center

3. Compare with source views:
   SELECT 'WC Batches' AS Source, COUNT(*) AS Rows FROM dbo.ETB2_Inventory_WC_Batches
   UNION ALL
   SELECT 'Unified Eligible', COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible
   -- Should show reduction due to quarantine exclusion
*/
