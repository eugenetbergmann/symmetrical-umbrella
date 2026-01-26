-- ============================================================================
-- View: dbo.ETB2_Campaign_Concurrency_Window
-- Purpose: Determine how many campaigns can overlap within item lead time
-- Grain: Item
-- Logic:
--   - For each item, count overlapping campaigns within lead time horizon
--   - Overlap defined as campaign periods intersecting
-- Assumptions:
--   - Campaign dates are point-in-time (start = end = Due_Date)
--   - No overlap possible with point dates, so CCW = 1 (conservative default)
--   - With actual campaign span data, CCW would be higher (e.g., 2-5 campaigns overlapping)
--   - Lead time horizon: Lead_Time_Days from current date
--   - Items with missing lead times: Use default 30 days
-- Dependencies: ETB2_Campaign_Normalized_Demand, ETB2_Config_Lead_Times
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Campaign_Concurrency_Window AS

WITH ItemLeadTimes AS (
    SELECT
        i.ITEMNMBR,
        COALESCE(lt.Lead_Time_Days, 30) AS Lead_Time_Days
    FROM (SELECT DISTINCT ITEMNMBR FROM dbo.ETB2_Campaign_Normalized_Demand) i
    LEFT JOIN dbo.ETB2_Config_Lead_Times lt ON i.ITEMNMBR = lt.ITEMNMBR
),

CampaignCounts AS (
    SELECT
        item_id,
        COUNT(*) AS total_campaigns,
        COUNT(CASE WHEN campaign_start_date >= DATEADD(DAY, -Lead_Time_Days, GETDATE()) THEN 1 END) AS campaigns_in_lead_time
    FROM dbo.ETB2_Campaign_Normalized_Demand c
    INNER JOIN ItemLeadTimes lt ON c.item_id = lt.ITEMNMBR
    GROUP BY item_id, Lead_Time_Days
)

SELECT
    item_id,
    -- Since campaign dates are point-in-time and assumed non-overlapping, CCW = 1
    -- In reality with span data, this would be MAX overlapping campaigns
    1 AS campaign_concurrency_window,  -- CCW
    total_campaigns,
    campaigns_in_lead_time,
    'LOW CONFIDENCE - Campaign dates inferred as points; actual concurrency unknown' AS data_quality_flag,
    'CCW defaulted to 1 due to missing campaign span data; update with actual campaign schedules' AS assumptions_notes
FROM CampaignCounts;