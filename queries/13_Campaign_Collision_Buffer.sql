/*******************************************************************************
* View: ETB2_Campaign_Collision_Buffer
* Order: 13 of 17 ⚠️ DEPLOY THIRTEENTH
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Campaign_Normalized_Demand (file 11)
*   ✓ ETB2_Campaign_Concurrency_Window (file 12)
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
* 8. Save as: dbo.ETB2_Campaign_Collision_Buffer
*
* Expected Result: Buffer quantity = CCU × CCW × Pooling Multiplier
*******************************************************************************/

-- Copy from here ↓

SELECT
    n.ITEMNMBR,
    n.Campaign_ID,
    n.campaign_consumption_per_day AS CCU,
    COALESCE(w.campaign_concurrency_window, 0) AS CCW,
    CASE p.Pooling_Classification
        WHEN 'Pooled' THEN 1.5
        WHEN 'Mixed' THEN 1.2
        ELSE 1.0
    END AS Pooling_Multiplier,
    n.campaign_consumption_per_day * COALESCE(w.campaign_concurrency_window, 0) * 
        CASE p.Pooling_Classification
            WHEN 'Pooled' THEN 1.5
            WHEN 'Mixed' THEN 1.2
            ELSE 1.0
        END AS collision_buffer_qty
FROM dbo.ETB2_Campaign_Normalized_Demand n
LEFT JOIN dbo.ETB2_Campaign_Concurrency_Window w ON n.Campaign_ID = w.Campaign_ID
LEFT JOIN dbo.ETB2_Config_Part_Pooling p ON n.ITEMNMBR = p.ITEMNMBR;

-- Copy to here ↑
