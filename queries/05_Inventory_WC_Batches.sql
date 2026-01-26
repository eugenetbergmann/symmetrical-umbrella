/*******************************************************************************
* View Name:    ETB2_Inventory_WC_Batches
* Deploy Order: 05 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Work center inventory batches with FEFO ordering and expiry dates
* Grain:        One row per item per work center per batch
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (inventory - external table)
*   ✓ dbo.EXT_BINTYPE (bin types - external table)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Inventory_WC_Batches
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Inventory_WC_Batches
*   Expected: Positive inventory rows in work center locations
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    i.Item_Number AS ITEMNMBR,
    i.SITE AS Work_Center,
    i.Bin AS Batch_Number,
    i.QTY_Available AS Quantity,
    i.EXPNDATE AS Expiry_Date,
    DATEDIFF(DAY, GETDATE(), i.EXPNDATE) AS Days_To_Expiry,  -- Positive = future expiry
    -- FEFO rank: oldest expiry first (1 = expiring soonest)
    0 AS FEFO_Rank,  -- FEFO logic needs review based on available columns
    i.[QTY TYPE] AS Quantity_Type_Code,
    0 AS Is_FEFO_Enabled  -- FEFO flag not available
FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE i
WHERE i.QTY_Available > 0  -- Only positive quantities
    AND i.SITE LIKE 'WC[_-]%'  -- Work center locations only

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Row count check:
   SELECT COUNT(*) FROM dbo.ETB2_Inventory_WC_Batches
   -- Should show inventory in work centers

2. Work center distribution:
   SELECT 
       Work_Center,
       COUNT(*) AS Batches,
       SUM(Quantity) AS Total_Qty
   FROM dbo.ETB2_Inventory_WC_Batches
   GROUP BY Work_Center
   ORDER BY Work_Center

3. Expiry check:
   SELECT TOP 10
       ITEMNMBR,
       Work_Center,
       Expiry_Date,
       Days_To_Expiry
   FROM dbo.ETB2_Inventory_WC_Batches
   ORDER BY Days_To_Expiry ASC
   -- Items expiring soonest first
*/
