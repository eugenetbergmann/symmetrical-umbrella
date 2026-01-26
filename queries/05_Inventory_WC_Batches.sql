/*******************************************************************************
* View: ETB2_Inventory_WC_Batches
* Order: 05 of 17 ⚠️ DEPLOY FIFTH
* 
* Dependencies (MUST exist first):
*   ✓ dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (external table - must exist)
*   ✓ dbo.EXT_BINTYPE (external table - must exist)
*
* External Tables Required:
*   ✓ dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
*   ✓ dbo.EXT_BINTYPE
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Inventory_WC_Batches
*
* Expected Result: Inventory batches with FEFO ordering
*******************************************************************************/

-- Copy from here ↓

SELECT
    i.ITEMNMBR,
    i.LOCNID AS Work_Center,
    i.BIN AS Batch_Number,
    i.QTY AS Quantity,
    i.EXTDATE AS Expiry_Date,
    CASE 
        WHEN e.FEFO_FLAG = 1 THEN ROW_NUMBER() OVER (PARTITION BY i.ITEMNMBR, i.LOCNID ORDER BY i.EXTDATE ASC)
        ELSE 0
    END AS FEFO_Rank
FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE i
LEFT JOIN dbo.EXT_BINTYPE e ON i.QTYTYPE = e.BINTYPE
WHERE i.QTY > 0;

-- Copy to here ↑
