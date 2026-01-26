/*******************************************************************************
* View: ETB2_Inventory_Unified_Eligible
* Order: 07 of 17 ⚠️ DEPLOY SEVENTH
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Inventory_WC_Batches (file 05)
*   ✓ ETB2_Inventory_Quarantine_Restricted (file 06)
*
* External Tables Required:
*   ✓ dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
*   ✓ dbo.IV00300
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Inventory_Unified_Eligible
*
* Expected Result: All eligible inventory combined from multiple sources
*******************************************************************************/

-- Copy from here ↓

SELECT
    ITEMNMBR,
    'WC_Batch' AS Source_Type,
    Quantity AS Available_Qty,
    Work_Center AS Location,
    'Eligible' AS Status
FROM dbo.ETB2_Inventory_WC_Batches
WHERE FEFO_Rank <= 5 OR FEFO_Rank = 0

UNION ALL

SELECT
    ITEMNMBR,
    'Quarantine' AS Source_Type,
    Quantity AS Available_Qty,
    Location,
    'Quarantine' AS Status
FROM dbo.ETB2_Inventory_Quarantine_Restricted;

-- Copy to here ↑
