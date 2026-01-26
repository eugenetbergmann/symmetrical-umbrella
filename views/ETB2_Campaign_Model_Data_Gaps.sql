-- ============================================================================
-- View: dbo.ETB2_Campaign_Model_Data_Gaps
-- Purpose: Flag items with missing or inferred data in campaign model
-- Grain: Item
-- Notes:
--   - Human-readable report of data quality issues
--   - All items currently flagged due to missing campaign structure
--   - Update underlying data sources to improve model accuracy
-- Dependencies: Various ETB2 views
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Campaign_Model_Data_Gaps AS

SELECT
    i.ITEMNMBR AS item_id,
    i.ITEMDESC AS item_description,
    CASE WHEN lt.Lead_Time_Days = 30 THEN 'Y' ELSE 'N' END AS lead_times_missing_default_used,
    CASE WHEN p.Pooling_Class = 'Dedicated' THEN 'Y' ELSE 'N' END AS pooling_not_classified_default_used,
    'Y' AS campaign_ids_missing_ordernumber_used,
    'Y' AS campaign_dates_inferred_as_points,
    'Campaign model operates with LOW CONFIDENCE due to missing campaign management data' AS overall_data_quality,
    'Integrate with campaign planning system to provide actual campaign IDs, start/end dates, and groupings' AS recommended_action
FROM dbo.IV00101 i
LEFT JOIN dbo.ETB2_Config_Lead_Times lt ON i.ITEMNMBR = lt.ITEMNMBR
LEFT JOIN dbo.ETB2_Config_Part_Pooling p ON i.ITEMNMBR = p.ITEMNMBR
WHERE i.ITEMNMBR IN (SELECT DISTINCT ITEMNMBR FROM dbo.ETB2_Demand_Cleaned_Base);