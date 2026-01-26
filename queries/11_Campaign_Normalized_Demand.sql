/*******************************************************************************
* View: ETB2_Campaign_Normalized_Demand
* Order: 11 of 17 ⚠️ DEPLOY ELEVENTH
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Demand_Cleaned_Base (file 04)
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
* 8. Save as: dbo.ETB2_Campaign_Normalized_Demand
*
* Expected Result: Campaign consumption units normalized
*******************************************************************************/

-- Copy from here ↓

SELECT
    d.Campaign_ID,
    d.ITEMNMBR,
    SUM(d.Quantity) / 30 AS campaign_consumption_per_day,
    'DAILY' AS campaign_consumption_unit,
    MIN(d.Demand_Date) AS Peak_Period_Start,
    MAX(d.Demand_Date) AS Peak_Period_End
FROM dbo.ETB2_Demand_Cleaned_Base d
WHERE d.Campaign_ID IS NOT NULL
GROUP BY d.Campaign_ID, d.ITEMNMBR;

-- Copy to here ↑
