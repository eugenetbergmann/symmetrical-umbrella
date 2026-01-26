-- ============================================================================
-- View: dbo.ETB2_Campaign_Risk_Adequacy
-- Purpose: Assess inventory adequacy against campaign collision risk
-- Grain: Item
-- Logic:
--   - Total available = On-hand + Inbound supply
--   - Required = Collision buffer + Firm campaign commitments (0-90 days)
--   - Can absorb: Y if available >= required
--   - Risk level: LOW if can absorb, MED if available >= commitments but < required, HIGH otherwise
-- Assumptions:
--   - Inbound supply: Sum of PO commitments and receipts due in future
--   - Firm commitments: Demand due in next 90 days
--   - No labeling as "stockouts" - focus on collision absorption capacity
-- Dependencies: ETB2_Inventory_Unified_Eligible, ETB2_PAB_EventLedger_v1, ETB2_Demand_Cleaned_Base, ETB2_Campaign_Collision_Buffer
-- Last Updated: 2026-01-26
-- ============================================================================

WITH OnHand AS (
    SELECT
        Item_Number,
        SUM(Quantity) AS on_hand_qty
    FROM dbo.ETB2_Inventory_Unified_Eligible
    GROUP BY Item_Number
),

Inbound AS (
    SELECT
        ITEMNMBR,
        SUM([PO's]) AS inbound_qty
    FROM dbo.ETB2_PAB_EventLedger_v1
    WHERE EventType IN ('PO_COMMITMENT', 'PO_RECEIPT')
      AND DUEDATE >= CAST(GETDATE() AS DATE)
    GROUP BY ITEMNMBR
),

FirmCommitments AS (
    SELECT
        ITEMNMBR,
        SUM(Base_Demand) AS firm_commitments_90_days
    FROM dbo.ETB2_Demand_Cleaned_Base
    WHERE DUEDATE BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    GROUP BY ITEMNMBR
),

ItemData AS (
    SELECT
        COALESCE(oh.Item_Number, ib.ITEMNMBR, fc.ITEMNMBR, cb.item_id) AS item_id,
        COALESCE(oh.on_hand_qty, 0) AS on_hand_qty,
        COALESCE(ib.inbound_qty, 0) AS inbound_qty,
        COALESCE(fc.firm_commitments_90_days, 0) AS firm_commitments_90_days,
        cb.collision_buffer_qty
    FROM dbo.ETB2_Campaign_Collision_Buffer cb
    FULL OUTER JOIN OnHand oh ON cb.item_id = oh.Item_Number
    FULL OUTER JOIN Inbound ib ON cb.item_id = ib.ITEMNMBR
    FULL OUTER JOIN FirmCommitments fc ON cb.item_id = fc.ITEMNMBR
)

SELECT
    item_id,
    on_hand_qty,
    inbound_qty,
    firm_commitments_90_days,
    collision_buffer_qty,
    (on_hand_qty + inbound_qty) AS total_available,
    (collision_buffer_qty + firm_commitments_90_days) AS required_for_collision_absorption,
    CASE
        WHEN (on_hand_qty + inbound_qty) >= (collision_buffer_qty + firm_commitments_90_days) THEN 'Y'
        ELSE 'N'
    END AS can_absorb_campaign_collision,
    CASE
        WHEN (on_hand_qty + inbound_qty) >= (collision_buffer_qty + firm_commitments_90_days) THEN 'LOW'
        WHEN (on_hand_qty + inbound_qty) >= firm_commitments_90_days THEN 'MED'
        ELSE 'HIGH'
    END AS campaign_collision_risk
FROM ItemData;