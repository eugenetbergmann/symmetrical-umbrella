-- ============================================================================
-- View: dbo.ETB2_Campaign_Absorption_Capacity
-- Purpose: Calculate how many campaigns the system can absorb
-- Grain: Item
-- Logic: absorbable_campaigns = (On-Hand + Inbound) ÷ CCU
-- Notes:
--   - Primary executive KPI for campaign capacity
--   - Segmented by pooling class and lead time bucket
--   - CCU is max campaign consumption per item
-- Dependencies: ETB2_Campaign_Collision_Buffer, ETB2_Campaign_Risk_Adequacy, ETB2_Config_Lead_Times, ETB2_Config_Part_Pooling
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Campaign_Absorption_Capacity AS

WITH LeadTimeBuckets AS (
    SELECT
        ITEMNMBR,
        Lead_Time_Days,
        CASE
            WHEN Lead_Time_Days < 30 THEN '<30 days'
            WHEN Lead_Time_Days <= 60 THEN '30-60 days'
            ELSE '>60 days'
        END AS lead_time_bucket
    FROM dbo.ETB2_Config_Lead_Times
)

SELECT
    cb.item_id,
    (ra.on_hand_qty + ra.inbound_qty) / NULLIF(cb.CCU, 0) AS absorbable_campaigns,
    p.Pooling_Class AS pooling_class,
    ltb.lead_time_bucket,
    cb.CCU,
    ra.on_hand_qty + ra.inbound_qty AS total_available_qty,
    'Primary KPI: How many campaigns can be absorbed before collision risk' AS kpi_description
FROM dbo.ETB2_Campaign_Collision_Buffer cb
INNER JOIN dbo.ETB2_Campaign_Risk_Adequacy ra ON cb.item_id = ra.item_id
INNER JOIN dbo.ETB2_Config_Part_Pooling p ON cb.item_id = p.ITEMNMBR
LEFT JOIN LeadTimeBuckets ltb ON cb.item_id = ltb.ITEMNMBR;