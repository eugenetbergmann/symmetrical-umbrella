/*******************************************************************************
* View: ETB2_Campaign_Model_Data_Gaps
* Order: 16 of 17 ⚠️ DEPLOY LAST (after file 15)
* 
* Dependencies (MUST exist first):
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
* 8. Save as: dbo.ETB2_Campaign_Model_Data_Gaps
*
* Expected Result: Data quality flags for missing configuration
*******************************************************************************/

-- Copy from here ↓

SELECT
    c.ITEMNMBR,
    CASE WHEN c.Lead_Time_Days IS NULL THEN 1 ELSE 0 END AS Missing_Config,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_WC_Batches) THEN 1 ELSE 0 END AS Missing_Inventory,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END AS Missing_Demand,
    CASE 
        WHEN c.Lead_Time_Days IS NULL 
         OR c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_WC_Batches)
         OR c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base)
        THEN 'LOW'
        ELSE 'HIGH'
    END AS data_confidence,
    CASE 
        WHEN c.Lead_Time_Days IS NULL THEN 'Missing lead time configuration;'
        ELSE ''
    END + 
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_WC_Batches) THEN ' No inventory data;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN ' No demand history;'
        ELSE ''
    END AS Gap_Description
FROM dbo.ETB2_Config_Active c
WHERE c.Config_Level = 'Item';

-- Copy to here ↑
