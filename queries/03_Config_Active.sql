/*******************************************************************************
* View: ETB2_Config_Active
* Order: 03 of 17 ⚠️ DEPLOY THIRD
* 
* Dependencies (MUST exist first):
*   ✓ Table: ETB2_Config_Lead_Times (created in step 01)
*   ✓ Table: ETB2_Config_Part_Pooling (created in step 02)
*
* External Tables Required:
*   (none)
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Config_Active
*
* Expected Result: Multi-tier config with Item/Client/Global hierarchy
*******************************************************************************/

-- Copy from here ↓

SELECT
    COALESCE(ic.ITEMNMBR, cc.ITEMNMBR, gc.ITEMNMBR) AS ITEMNMBR,
    COALESCE(ic.Client, cc.Client, 'GLOBAL') AS Client,
    COALESCE(ic.Lead_Time_Days, cc.Lead_Time_Days, gc.Lead_Time_Days, 30) AS Lead_Time_Days,
    COALESCE(ic.Pooling_Classification, cc.Pooling_Classification, gc.Pooling_Classification, 'Dedicated') AS Pooling_Classification,
    CASE 
        WHEN ic.ITEMNMBR IS NOT NULL THEN 'Item'
        WHEN cc.ITEMNMBR IS NOT NULL THEN 'Client'
        ELSE 'Global'
    END AS Config_Level
FROM dbo.ETB2_Config_Lead_Times ic
FULL OUTER JOIN dbo.ETB2_Config_Part_Pooling cc ON ic.ITEMNMBR = cc.ITEMNMBR
FULL OUTER JOIN (
    SELECT DISTINCT ITEMNMBR, Lead_Time_Days, Pooling_Classification
    FROM dbo.ETB2_Config_Lead_Times
    WHERE ITEMNMBR = 'GLOBAL_DEFAULT'
) gc ON 1=1;

-- Copy to here ↑
