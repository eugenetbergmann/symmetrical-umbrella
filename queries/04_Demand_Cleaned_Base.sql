/*******************************************************************************
* View: ETB2_Demand_Cleaned_Base
* Order: 04 of 17 ⚠️ DEPLOY FOURTH
* 
* Dependencies (MUST exist first):
*   ✓ dbo.ETB_PAB_AUTO (external table - must exist)
*   ✓ dbo.Prosenthal_Vendor_Items (external table - must exist)
*
* External Tables Required:
*   ✓ dbo.ETB_PAB_AUTO
*   ✓ dbo.Prosenthal_Vendor_Items
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Demand_Cleaned_Base
*
* Expected Result: Cleaned demand data with normalized quantities
*******************************************************************************/

-- Copy from here ↓

SELECT
    d.ITEMNMBR,
    d.DUEDAT AS Demand_Date,
    SUM(d.QTYORDER) AS Quantity,
    'ETB_PAB_AUTO' AS Source,
    COALESCE(v.CUSTNMBR, 'UNKNOWN') AS Campaign_ID
FROM dbo.ETB_PAB_AUTO d
LEFT JOIN dbo.Prosenthal_Vendor_Items v ON d.ITEMNMBR = v.ITEMNMBR
WHERE d.POSTATUS <> 'CANCELLED'
    AND d.QTYORDER > 0
GROUP BY d.ITEMNMBR, d.DUEDAT, v.CUSTNMBR;

-- Copy to here ↑
