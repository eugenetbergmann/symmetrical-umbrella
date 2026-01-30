-- ============================================================================
-- VIEW 09: dbo.ETB2_Planning_Stockout (NEW)
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Planning_Stockout
-- ============================================================================
-- Purpose: ATP balance and shortage risk analysis
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Planning_Net_Requirements (view 08)
--   - dbo.ETB2_Inventory_Unified (view 07)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Last Updated: 2026-01-30
-- ============================================================================

WITH

-- Net requirements from demand
-- FG/Construct carried through from view 08
NetRequirements AS (
    SELECT
        Item_Number,
        Net_Requirement_Qty,
        Order_Count,
        Requirement_Priority,
        Requirement_Status,
        Earliest_Demand_Date,
        Latest_Demand_Date,
        -- FG SOURCE (PAB-style): Carried through from view 08
        FG_Item_Number,
        FG_Description,
        -- Construct SOURCE (PAB-style): Carried through from view 08
        Construct
    FROM dbo.ETB2_Planning_Net_Requirements WITH (NOLOCK)
    WHERE Net_Requirement_Qty > 0
),

-- Available inventory (all eligible)
-- FG/Construct aggregated from view 07
AvailableInventory AS (
    SELECT
        Item_Number,
        SUM(Usable_Qty) AS Total_Available,
        -- FG SOURCE (PAB-style): Carry primary FG from inventory
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        -- Construct SOURCE (PAB-style): Carry primary Construct from inventory
        MAX(Construct) AS Construct
    FROM dbo.ETB2_Inventory_Unified WITH (NOLOCK)
    GROUP BY Item_Number
)

-- ============================================================
-- FINAL OUTPUT: 18 columns, planner-optimized order
-- ============================================================
SELECT
    -- IDENTIFY (what item?) - 4 columns
    COALESCE(nr.Item_Number, ai.Item_Number) AS Item_Number,
    ci.Item_Description,
    ci.UOM_Schedule AS Unit_Of_Measure_Schedule,
    
    -- QUANTIFY (the math) - 4 columns
    COALESCE(nr.Net_Requirement_Qty, 0) AS Net_Requirement,
    COALESCE(ai.Total_Available, 0) AS Total_Available,
    COALESCE(ai.Total_Available, 0) - COALESCE(nr.Net_Requirement_Qty, 0) AS ATP_Balance,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0)
        THEN COALESCE(nr.Net_Requirement_Qty, 0) - COALESCE(ai.Total_Available, 0)
        ELSE 0
    END AS Shortage_Quantity,

    -- DECIDE (risk assessment) - 5 columns
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 'CRITICAL'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 'HIGH'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Risk_Level,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) > 0 AND COALESCE(nr.Net_Requirement_Qty, 0) > 0
        THEN CAST(COALESCE(ai.Total_Available, 0) / NULLIF(COALESCE(nr.Net_Requirement_Qty, 0), 0) AS decimal(10,2))
        ELSE 999.99
    END AS Coverage_Ratio,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 1
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 2
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 3
        ELSE 4
    END AS Priority,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 'URGENT: No inventory'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 'EXPEDITE: Low coverage'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 'MONITOR: Partial coverage'
        ELSE 'OK: Adequate coverage'
    END AS Recommendation,
    nr.Requirement_Priority,
    nr.Requirement_Status,

    -- FG SOURCE (PAB-style): Coalesce from demand and inventory sources
    COALESCE(nr.FG_Item_Number, ai.FG_Item_Number) AS FG_Item_Number,
    COALESCE(nr.FG_Description, ai.FG_Description) AS FG_Description,
    -- Construct SOURCE (PAB-style): Coalesce from demand and inventory sources
    COALESCE(nr.Construct, ai.Construct) AS Construct

FROM NetRequirements nr
FULL OUTER JOIN AvailableInventory ai
    ON nr.Item_Number = ai.Item_Number
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON COALESCE(nr.Item_Number, ai.Item_Number) = ci.Item_Number

WHERE COALESCE(nr.Net_Requirement_Qty, 0) > 0
   OR COALESCE(ai.Total_Available, 0) > 0;

-- ============================================================================
-- END OF VIEW 09
-- ============================================================================
