/*******************************************************************************
* View: ETB2_Campaign_Concurrency_Window
* Order: 12 of 17 ⚠️ DEPLOY TWELFTH
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Campaign_Normalized_Demand (file 11)
*   ✓ ETB2_Config_Active (file 03)
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
* 8. Save as: dbo.ETB2_Campaign_Concurrency_Window
*
* Expected Result: Campaign overlap calculation in days
*******************************************************************************/

-- Copy from here ↓

SELECT
    a.Campaign_ID,
    b.Campaign_ID AS Overlapping_Campaign,
    DATEDIFF(DAY, a.Peak_Period_Start, b.Peak_Period_End) AS campaign_concurrency_window,
    CASE 
        WHEN a.Peak_Period_Start < b.Peak_Period_End 
        THEN a.Peak_Period_Start 
        ELSE b.Peak_Period_Start 
    END AS Overlap_Start,
    CASE 
        WHEN a.Peak_Period_End > b.Peak_Period_Start 
        THEN a.Peak_Period_End 
        ELSE b.Peak_Period_End 
    END AS Overlap_End
FROM dbo.ETB2_Campaign_Normalized_Demand a
JOIN dbo.ETB2_Campaign_Normalized_Demand b ON a.ITEMNMBR = b.ITEMNMBR
WHERE a.Campaign_ID <> b.Campaign_ID;

-- Copy to here ↑
