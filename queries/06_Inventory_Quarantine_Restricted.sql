/*******************************************************************************
* View: ETB2_Inventory_Quarantine_Restricted
* Order: 06 of 17 ⚠️ DEPLOY SIXTH
* 
* Dependencies (MUST exist first):
*   ✓ dbo.IV00300 (external table - must exist)
*   ✓ dbo.IV00101 (external table - must exist)
*
* External Tables Required:
*   ✓ dbo.IV00300
*   ✓ dbo.IV00101
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Inventory_Quarantine_Restricted
*
* Expected Result: Quarantined and restricted inventory with hold periods
*******************************************************************************/

-- Copy from here ↓

SELECT
    i.ITEMNMBR,
    i.LOCNID AS Location,
    (i.QTYOH - i.QTYCOMTD) AS Quantity,
    CASE 
        WHEN i.QTYRCTD > i.QTYSOLD THEN 'WFQ'
        ELSE 'RMQTY'
    END AS Restriction_Type,
    DATEADD(DAY, 30, GETDATE()) AS Hold_Until,
    'Quality Review' AS Reason_Code
FROM dbo.IV00300 i
WHERE (i.QTYOH - i.QTYCOMTD) > 0;

-- Copy to here ↑
