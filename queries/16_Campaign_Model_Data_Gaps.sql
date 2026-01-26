/*******************************************************************************
* View Name:    ETB2_Campaign_Model_Data_Gaps
* Deploy Order: 16 of 17
* 
* Purpose:      Data quality flags and confidence levels for model inputs
* Grain:        One row per item from active configuration
* 
* Dependencies:
*   ✓ dbo.ETB2_Config_Active (view 03)
*   ✓ dbo.ETB2_Config_Part_Pooling (view 02)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Campaign_Model_Data_Gaps
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Campaign_Model_Data_Gaps
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    c.ITEMNMBR,
    -- Gap indicators (1 = gap exists, 0 = no gap)
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Source = 'SYSTEM_DEFAULT' THEN 1 ELSE 0 END AS Missing_Lead_Time_Config,
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Source = 'SYSTEM_DEFAULT' THEN 1 ELSE 0 END AS Missing_Pooling_Config,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_WC_Batches) THEN 1 ELSE 0 END AS Missing_Inventory_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END AS Missing_Demand_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Missing_Campaign_Data,
    -- Count of gaps
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Source = 'SYSTEM_DEFAULT' THEN 1 ELSE 0 END +
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Source = 'SYSTEM_DEFAULT' THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_WC_Batches) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Total_Gap_Count,
    -- Confidence level (LOW until campaign structure data is complete)
    'LOW' AS data_confidence,
    -- Gap descriptions for remediation
    CASE 
        WHEN c.Lead_Time_Days = 30 AND c.Config_Source = 'SYSTEM_DEFAULT' THEN 'Lead time uses system default (30 days);'
        ELSE ''
    END +
    CASE 
        WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Source = 'SYSTEM_DEFAULT' THEN 'Pooling classification uses system default (Dedicated);'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_WC_Batches) THEN ' No inventory data in work centers;'
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
    -- Remediation priority
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1
        WHEN c.ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Inventory_WC_Batches) THEN 2
        ELSE 3
    END AS Remediation_Priority
FROM dbo.ETB2_Config_Active c

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
