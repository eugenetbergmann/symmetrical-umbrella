/*******************************************************************************
* View: ETB2_Campaign_Absorption_Capacity
* Order: 15 of 17 ⚠️ DEPLOY AFTER FILE 14
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Campaign_Collision_Buffer (file 13)
*   ✓ ETB2_Campaign_Risk_Adequacy (file 14)
*   ✓ ETB2_Config_Active (file 03)
*   ✓ ETB2_Config_Part_Pooling (file 02)
*
* External Tables Required:
*   (none - uses ETB2 views only)
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Campaign_Absorption_Capacity
*
* Expected Result: Executive capacity KPI with absorbable campaigns count
*******************************************************************************/

-- Copy from here ↓

SELECT
    b.ITEMNMBR,
    COUNT(DISTINCT b.Campaign_ID) AS absorbable_campaigns,
    SUM(b.collision_buffer_qty) AS Total_Buffer_Required,
    CASE 
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 5 THEN 1.0
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 3 THEN 0.7
        ELSE 0.4
    END AS Utilization_Pct,
    CASE 
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 5 THEN 'Green'
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 3 THEN 'Yellow'
        ELSE 'Red'
    END AS Risk_Status
FROM dbo.ETB2_Campaign_Collision_Buffer b
GROUP BY b.ITEMNMBR;

-- Copy to here ↑
