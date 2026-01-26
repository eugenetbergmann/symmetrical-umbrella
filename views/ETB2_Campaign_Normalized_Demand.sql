-- ============================================================================
-- View: dbo.ETB2_Campaign_Normalized_Demand
-- Purpose: Normalize demand into campaign execution units
-- Grain: Campaign
-- Assumptions:
--   - Campaign ID: Using ORDERNUMBER as proxy for campaign_id (each order assumed to be a separate campaign)
--   - Campaign boundaries: Inferred as point-in-time (start_date = end_date = Due_Date)
--     This is a conservative assumption that may underestimate campaign overlap and concurrency
--   - CCU (Campaign Consumption Unit): Total item quantity per campaign
--   - Data quality: LOW CONFIDENCE due to missing explicit campaign structure
--   - Recommendation: Integrate with actual campaign management system for accurate dates and groupings
-- Dependencies: ETB2_Demand_Cleaned_Base
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Campaign_Normalized_Demand AS

SELECT
    d.ITEMNMBR AS item_id,
    d.ORDERNUMBER AS campaign_id,
    d.DUEDATE AS campaign_start_date,
    d.DUEDATE AS campaign_end_date,
    d.Base_Demand AS campaign_consumption_unit,  -- CCU
    'LOW CONFIDENCE' AS data_quality_flag,
    'Campaign dates inferred as point-in-time from order due dates; actual campaign spans unknown' AS assumptions_notes
FROM dbo.ETB2_Demand_Cleaned_Base d
WHERE d.Base_Demand > 0;