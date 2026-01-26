/*******************************************************************************
* View: ETB2_Planning_Net_Requirements
* Order: 09 of 17 ⚠️ DEPLOY NINTH
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
* 8. Save as: dbo.ETB2_Planning_Net_Requirements
*
* Expected Result: Procurement requirements with priority scores
*******************************************************************************/

-- Copy from here ↓

SELECT
    d.ITEMNMBR,
    SUM(d.Quantity) - SUM(i.Quantity) AS Projected_Shortage,
    COALESCE(c.Lead_Time_Days, 30) AS Lead_Time_Adjustment,
    CASE 
        WHEN SUM(d.Quantity) - SUM(i.Quantity) > 0 
        THEN (SUM(d.Quantity) - SUM(i.Quantity)) * 1.1 
        ELSE 0 
    END AS Recommended_Order_Qty,
    CASE 
        WHEN SUM(d.Quantity) - SUM(i.Quantity) > 0 
        THEN SUM(d.Quantity) - SUM(i.Quantity)
        ELSE 0 
    END AS Net_Requirement_Quantity,
    CASE 
        WHEN SUM(d.Quantity) - SUM(i.Quantity) > 1000 THEN 1
        WHEN SUM(d.Quantity) - SUM(i.Quantity) > 500 THEN 2
        ELSE 3
    END AS Priority_Score
FROM dbo.ETB2_Demand_Cleaned_Base d
LEFT JOIN dbo.ETB2_Inventory_WC_Batches i ON d.ITEMNMBR = i.ITEMNMBR
LEFT JOIN dbo.ETB2_Config_Active c ON d.ITEMNMBR = c.ITEMNMBR
GROUP BY d.ITEMNMBR, c.Lead_Time_Days;

-- Copy to here ↑
