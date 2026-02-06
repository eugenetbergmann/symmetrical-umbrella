/* VIEW 08 - STATUS: PRODUCTION STABILIZED */
-- ============================================================================
-- VIEW 08: dbo.ETB2_Planning_Net_Requirements (PRODUCTION STABILIZED)
-- ============================================================================
-- Purpose: Net requirements calculation from demand within planning window
--          SUPPRESSION-SAFE: Uses suppressed quantities for accurate PAB math
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
--   - dbo.ETB2_Config_Items (view 02B)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct aggregated from demand (view 04)
--   - Is_Suppressed flag: Propagated from source
-- Stabilization:
--   - Math Correctness: Uses Suppressed_Demand_Qty for net requirements
--   - Suppression Integrity: Suppressed items contribute 0 to net requirements
-- Last Updated: 2026-02-06
-- ============================================================================

WITH Demand_Aggregated AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        Item_Number,
        -- Use SUPPRESSED quantities for PAB math correctness
        SUM(COALESCE(TRY_CAST(Suppressed_Demand_Qty AS NUMERIC(18, 4)), 0)) AS Total_Demand,
        COUNT(DISTINCT CAST(Due_Date AS DATE)) AS Demand_Days,
        COUNT(DISTINCT Order_Number) AS Order_Count,
        MIN(CAST(Due_Date AS DATE)) AS Earliest_Demand_Date,
        MAX(CAST(Due_Date AS DATE)) AS Latest_Demand_Date,
        
        -- FG SOURCE (PAB-style): Carry primary FG from demand (view 04)
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        -- Construct SOURCE (PAB-style): Carry primary Construct from demand (view 04)
        MAX(Construct) AS Construct,
        
        -- Suppression flag (aggregate - if any suppressed, mark all)
        MAX(CASE WHEN Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Has_Suppressed
        
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
      AND Item_Number NOT LIKE 'MO-%'
    GROUP BY client, contract, run, Item_Number
)
SELECT
    -- Context columns preserved
    da.client,
    da.contract,
    da.run,
    
    da.Item_Number,
    ci.Item_Description,
    ci.UOM_Schedule,
    
    -- SUPPRESSED NET REQUIREMENT: Accurate PAB math
    CAST(da.Total_Demand AS NUMERIC(18, 4)) AS Net_Requirement_Qty,
    
    -- Expose suppressed quantity for audit
    CASE WHEN da.Has_Suppressed = 1 THEN 
        (SELECT SUM(COALESCE(TRY_CAST(Deductions_Qty AS NUMERIC(18, 4)), 0))
         FROM dbo.ETB2_Demand_Cleaned_Base dcb
         WHERE dcb.Item_Number = da.Item_Number
           AND dcb.client = da.client
           AND dcb.contract = da.contract
           AND dcb.run = da.run
           AND dcb.Is_Suppressed = 1)
    ELSE 0 END AS Suppressed_Demand_Qty,
    
    CAST(0 AS NUMERIC(18, 4)) AS Safety_Stock_Level,
    da.Demand_Days AS Days_Of_Supply,
    da.Order_Count,
    
    -- Priority based on SUPPRESSED demand
    CASE
        WHEN da.Total_Demand = 0 AND da.Has_Suppressed = 1 THEN 'SUPPRESSED'
        WHEN da.Total_Demand = 0 THEN 'NONE'
        WHEN da.Total_Demand <= 100 THEN 'LOW'
        WHEN da.Total_Demand <= 500 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS Requirement_Priority,
    
    CASE
        WHEN da.Total_Demand = 0 AND da.Has_Suppressed = 1 THEN 'SUPPRESSED'
        WHEN da.Total_Demand = 0 THEN 'NO_DEMAND'
        WHEN da.Total_Demand <= 100 THEN 'LOW_PRIORITY'
        WHEN da.Total_Demand <= 500 THEN 'MEDIUM_PRIORITY'
        ELSE 'HIGH_PRIORITY'
    END AS Requirement_Status,
    
    da.Earliest_Demand_Date,
    da.Latest_Demand_Date,
    
    -- FG SOURCE (PAB-style): Carried through from demand aggregation (view 04)
    da.FG_Item_Number,
    da.FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from demand aggregation (view 04)
    da.Construct,
    
    -- Suppression flag
    CAST(CASE WHEN da.Has_Suppressed = 1 OR COALESCE(ci.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END AS BIT) AS Is_Suppressed
    
FROM Demand_Aggregated da
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON da.Item_Number = ci.Item_Number
    AND da.client = ci.client
    AND da.contract = ci.contract
    AND da.run = ci.run
WHERE da.Item_Number NOT LIKE 'MO-%';

-- ============================================================================
-- END OF VIEW 08 (PRODUCTION STABILIZED)
-- ============================================================================
