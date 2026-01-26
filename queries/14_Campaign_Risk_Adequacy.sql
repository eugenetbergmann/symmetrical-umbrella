/*******************************************************************************
* View: ETB2_Campaign_Risk_Adequacy
* Order: 14 of 17 ⚠️ DEPLOY AFTER FILE 17 (EventLedger)
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Inventory_Unified_Eligible (file 07)
*   ✓ ETB2_PAB_EventLedger_v1 (file 17 - MUST BE DEPLOYED FIRST)
*   ✓ ETB2_Demand_Cleaned_Base (file 04)
*   ✓ ETB2_Campaign_Collision_Buffer (file 13)
*
* External Tables Required:
*   ✓ dbo.ETB_PAB_AUTO
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
* 8. Save as: dbo.ETB2_Campaign_Risk_Adequacy
*
* Expected Result: Risk adequacy assessment with collision risk classification
*******************************************************************************/

-- Copy from here ↓

SELECT
    b.ITEMNMBR,
    b.Campaign_ID,
    SUM(i.Available_Qty) AS Available_Inventory,
    SUM(b.collision_buffer_qty) AS Required_Buffer,
    CASE 
        WHEN SUM(i.Available_Qty) < SUM(b.collision_buffer_qty) * 0.5 THEN 'High'
        WHEN SUM(i.Available_Qty) < SUM(b.collision_buffer_qty) THEN 'Medium'
        ELSE 'Low'
    END AS campaign_collision_risk,
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(SUM(i.Available_Qty) AS DECIMAL(10,2)) / SUM(b.collision_buffer_qty)
        ELSE 1.0
    END AS Adequacy_Score
FROM dbo.ETB2_Campaign_Collision_Buffer b
LEFT JOIN dbo.ETB2_Inventory_Unified_Eligible i ON b.ITEMNMBR = i.ITEMNMBR
GROUP BY b.ITEMNMBR, b.Campaign_ID;

-- Copy to here ↑
