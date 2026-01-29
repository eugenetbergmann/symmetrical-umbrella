/*******************************************************************************
 * View Name:    ETB2_Campaign_Model_Data_Gaps
 * Deploy Order: 16 of 17
 * Status:       🔴 NOT YET DEPLOYED
 * 
 * Purpose:      Data quality flags and confidence levels for model inputs
 * Grain:        One row per item from active configuration
 * 
 * Dependencies (MUST exist - verify first):
 *   ✅ ETB2_Config_Lead_Times (deployed)
 *   ✅ ETB2_Config_Part_Pooling (deployed)
 *   ✅ ETB2_Config_Active (deployed)
 *
 * ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
 * 1. Object Explorer → Right-click "Views" → "New View..."
 * 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
 * 3. Delete default SQL
 * 4. Copy SELECT below (between markers)
 * 5. Paste into SQL pane
 * 6. Execute (!) to test
 * 7. Save as: dbo.ETB2_Campaign_Model_Data_Gaps
 * 8. Refresh Views folder
 *
 * Validation: 
 *   SELECT COUNT(*) FROM dbo.ETB2_Campaign_Model_Data_Gaps
 *   Expected: One row per active item
 *******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    c.ITEMNMBR,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Lead_Time_Config,
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Pooling_Config,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_Unified) THEN 1 ELSE 0 END AS Missing_Inventory_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END AS Missing_Demand_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Missing_Campaign_Data,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_Unified) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Total_Gap_Count,
    'LOW' AS data_confidence,
    CASE 
        WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 'Lead time uses system default (30 days);'
        ELSE ''
    END +
    CASE 
        WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 'Pooling classification uses system default (Dedicated);'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_Unified) THEN ' No inventory data in work centers;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN ' No demand history;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Campaign_Normalized_Demand) THEN ' No campaign data.'
        ELSE ''
    END AS Gap_Description,
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_Unified) THEN 2
        ELSE 3
    END AS Remediation_Priority
FROM dbo.ETB2_Config_Active c WITH (NOLOCK);

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Gap summary:
   SELECT 
       Total_Gap_Count,
       COUNT(*) AS Items
   FROM dbo.ETB2_Campaign_Model_Data_Gaps
   GROUP BY Total_Gap_Count
   ORDER BY Total_Gap_Count;

2. Items with gaps:
   SELECT TOP 10
       ITEMNMBR,
       Total_Gap_Count,
       Gap_Description
   FROM dbo.ETB2_Campaign_Model_Data_Gaps
   WHERE Total_Gap_Count > 0
   ORDER BY Total_Gap_Count DESC, Remediation_Priority ASC;

3. Data confidence:
   SELECT 
       data_confidence,
       COUNT(*) AS Items
   FROM dbo.ETB2_Campaign_Model_Data_Gaps
   GROUP BY data_confidence;
*/
