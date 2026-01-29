-- ============================================================================
-- VIEW 16: dbo.ETB2_Campaign_Model_Data_Gaps
-- Deploy Order: 16 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Data quality flags and confidence levels for model inputs
-- Grain: One row per item from active configuration
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Model_Data_Gaps
-- ============================================================================

SELECT 
    c.ITEMNMBR AS Item_Number,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Lead_Time_Config,
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Pooling_Config,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN 1 ELSE 0 END AS Missing_Inventory_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END AS Missing_Demand_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Missing_Campaign_Data,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Total_Gap_Count,
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
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN ' No inventory data in work centers;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN ' No demand history;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Campaign_Normalized_Demand) THEN ' No campaign data.'
        ELSE ''
    END AS Gap_Description,
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN 2
        ELSE 3
    END AS Remediation_Priority
FROM dbo.ETB2_Config_Active c WITH (NOLOCK);

-- ============================================================================
-- END OF VIEW 16
-- ============================================================================
