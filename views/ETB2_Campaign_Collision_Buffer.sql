-- ============================================================================
-- View: dbo.ETB2_Campaign_Collision_Buffer
-- Purpose: Calculate campaign collision buffer to replace safety stock logic
-- Grain: Item
-- Logic: collision_buffer_qty = CCU × CCW × pooling_multiplier
-- Assumptions:
--   - CCU: Max campaign consumption unit per item (worst-case campaign size)
--   - CCW: Campaign concurrency window (default 1 due to missing data)
--   - Pooling multipliers: Pooled=0.6, Semi-Pooled=1.0, Dedicated=1.4
--   - This replaces daily-usage Z-score buffers with campaign-based risk
-- Dependencies: ETB2_Campaign_Normalized_Demand, ETB2_Campaign_Concurrency_Window, ETB2_Config_Part_Pooling
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Campaign_Collision_Buffer AS

WITH ItemCCU AS (
    SELECT
        item_id,
        MAX(campaign_consumption_unit) AS CCU  -- Use max CCU as representative for buffer calculation
    FROM dbo.ETB2_Campaign_Normalized_Demand
    GROUP BY item_id
),

PoolingMultipliers AS (
    SELECT
        ITEMNMBR,
        Pooling_Class,
        CASE Pooling_Class
            WHEN 'Pooled' THEN 0.6
            WHEN 'Semi-Pooled' THEN 1.0
            WHEN 'Dedicated' THEN 1.4  -- Chosen default for dedicated (between 1.3-1.5)
            ELSE 1.4  -- Default conservative
        END AS pooling_multiplier
    FROM dbo.ETB2_Config_Part_Pooling
)

SELECT
    c.item_id,
    c.CCU,
    cw.campaign_concurrency_window AS CCW,
    p.Pooling_Class AS pooling_class,
    p.pooling_multiplier,
    CAST(c.CCU * cw.campaign_concurrency_window * p.pooling_multiplier AS DECIMAL(19,5)) AS collision_buffer_qty,
    'Campaign collision buffer replaces traditional safety stock' AS buffer_type
FROM ItemCCU c
INNER JOIN dbo.ETB2_Campaign_Concurrency_Window cw ON c.item_id = cw.item_id
INNER JOIN PoolingMultipliers p ON c.item_id = p.ITEMNMBR;