/*******************************************************************************
* View: ETB2_Planning_Stockout_Risk
* Order: 08 of 17 ⚠️ DEPLOY EIGHTH
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Demand_Cleaned_Base (file 04)
*   ✓ ETB2_Inventory_WC_Batches (file 05)
*
* External Tables Required:
*   ✓ dbo.ETB_PAB_AUTO
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Planning_Stockout_Risk
*
* Expected Result: ATP calculation with risk classification
*******************************************************************************/

-- Copy from here ↓

SELECT
    d.ITEMNMBR,
    SUM(i.Quantity) AS Current_Inventory,
    SUM(d.Quantity) AS Projected_Demand,
    SUM(i.Quantity) - SUM(d.Quantity) AS ATP,
    CASE 
        WHEN SUM(i.Quantity) - SUM(d.Quantity) < 0 THEN 'High'
        WHEN SUM(i.Quantity) - SUM(d.Quantity) < 100 THEN 'Medium'
        ELSE 'Low'
    END AS Risk_Classification
FROM dbo.ETB2_Demand_Cleaned_Base d
LEFT JOIN dbo.ETB2_Inventory_WC_Batches i ON d.ITEMNMBR = i.ITEMNMBR
GROUP BY d.ITEMNMBR;

-- Copy to here ↑
