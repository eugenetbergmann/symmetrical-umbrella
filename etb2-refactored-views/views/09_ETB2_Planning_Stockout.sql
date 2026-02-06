/* VIEW 09 - STATUS: PRODUCTION STABILIZED */
-- ============================================================================
-- VIEW 09: dbo.ETB2_Planning_Stockout (PRODUCTION STABILIZED)
-- ============================================================================
-- Purpose: ATP balance and shortage risk analysis
--          SUPPRESSION-SAFE: Uses suppressed quantities for PAB math
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Planning_Net_Requirements (view 08)
--   - dbo.ETB2_Inventory_Unified (view 07)
--   - dbo.ETB2_Config_Items (view 02B)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct coalesced from demand (view 08) and inventory (view 07) sources
--   - Is_Suppressed flag: Propagated from source views
-- Stabilization:
--   - Math Correctness: Uses Suppressed_Demand_Qty for PAB calculations
--   - Suppression Integrity: Suppressed items don't contribute to shortage calculations
-- Last Updated: 2026-02-06
-- ============================================================================

WITH
-- Net requirements from demand
-- Uses SUPPRESSED quantities to ensure suppressed items don't erode balance
NetRequirements AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        Item_Number,
        -- Use SUPPRESSED quantities for PAB math correctness
        SUM(COALESCE(TRY_CAST(Suppressed_Demand_Qty AS NUMERIC(18, 4)), 0)) AS Net_Requirement_Qty,
        COUNT(DISTINCT Order_Number) AS Order_Count,
        MIN(Event_Sort_Priority) AS Requirement_Priority,
        CASE
            WHEN SUM(COALESCE(TRY_CAST(Suppressed_Demand_Qty AS NUMERIC(18, 4)), 0)) = 0 THEN 'SUPPRESSED'
            WHEN SUM(COALESCE(TRY_CAST(Suppressed_Demand_Qty AS NUMERIC(18, 4)), 0)) <= 100 THEN 'LOW'
            WHEN SUM(COALESCE(TRY_CAST(Suppressed_Demand_Qty AS NUMERIC(18, 4)), 0)) <= 500 THEN 'MEDIUM'
            ELSE 'HIGH'
        END AS Requirement_Status,
        MIN(CAST(Due_Date AS DATE)) AS Earliest_Demand_Date,
        MAX(CAST(Due_Date AS DATE)) AS Latest_Demand_Date,
        
        -- FG SOURCE (PAB-style): Carried through from view 08
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        -- Construct SOURCE (PAB-style): Carried through from view 08
        MAX(Construct) AS Construct,
        
        -- Suppression flag (aggregate - if any suppressed, mark all)
        MAX(CASE WHEN Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Has_Suppressed
        
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
      AND Item_Number NOT LIKE 'MO-%'
    GROUP BY client, contract, run, Item_Number
),

-- Available inventory (all eligible)
-- FG/Construct aggregated from view 07
AvailableInventory AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        Item_Number,
        SUM(Usable_Qty) AS Total_Available,
        -- FG SOURCE (PAB-style): Carry primary FG from inventory (view 07)
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        -- Construct SOURCE (PAB-style): Carry primary Construct from inventory (view 07)
        MAX(Construct) AS Construct,
        MAX(CASE WHEN Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Has_Suppressed
    FROM dbo.ETB2_Inventory_Unified WITH (NOLOCK)
    WHERE Item_Number NOT LIKE 'MO-%'
    GROUP BY client, contract, run, Item_Number
),

-- ============================================================================
-- PAB Running Balance Calculation (The Ledger)
-- Self-contained PAB math. Subtracts suppressed demand only. No window functions.
-- Uses correlated scalar subqueries for deterministic performance.
-- ============================================================================
EventStream AS (
    -- 1. BEG BAL (Priority 1) - Not available in source, will be added from inventory
    SELECT 
        Item_Number,
        CAST(GETDATE() AS DATE) AS E_Date,
        1 AS E_Pri,
        Total_Available AS Delta,
        'BEGIN' AS Type,
        client,
        contract,
        run
    FROM AvailableInventory
    
    UNION ALL
    
    -- 2. DEDUCTIONS (Priority 2) - SUBTRACT POST-SUPPRESSION
    SELECT 
        Item_Number,
        Due_Date AS E_Date,
        2 AS E_Pri,
        (Suppressed_Deductions_Qty * -1) AS Delta,
        'DEMAND' AS Type,
        client,
        contract,
        run
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
      AND Suppressed_Deductions_Qty > 0
    
    UNION ALL
    
    -- 3. EXPIRY (Priority 3) - ADD (treated as supply)
    SELECT 
        Item_Number,
        Expiry_Date AS E_Date,
        3 AS E_Pri,
        Suppressed_Expiry_Qty AS Delta,
        'EXPIRY' AS Type,
        client,
        contract,
        run
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
      AND Suppressed_Expiry_Qty > 0
),

-- Calculate running PAB using correlated subquery (no window functions)
LedgerCalculation AS (
    SELECT 
        e1.Item_Number,
        e1.client,
        e1.contract,
        e1.run,
        e1.E_Date,
        e1.Type,
        e1.Delta,
        e1.E_Pri,
        -- Correlated subquery for running balance (deterministic, no window functions)
        (SELECT SUM(e2.Delta) 
         FROM EventStream e2 
         WHERE e2.Item_Number = e1.Item_Number 
           AND e2.client = e1.client
           AND e2.contract = e1.contract
           AND e2.run = e1.run
           AND (e2.E_Date < e1.E_Date 
                OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri))
        ) AS Running_PAB
    FROM EventStream e1
),

-- Identify stockout events (PAB < 0)
StockoutEvents AS (
    SELECT
        Item_Number,
        client,
        contract,
        run,
        E_Date AS Stockout_Date,
        Running_PAB AS Deficit_Qty,
        ROW_NUMBER() OVER (PARTITION BY Item_Number, client, contract, run ORDER BY E_Date) AS Stockout_Seq
    FROM LedgerCalculation
    WHERE Running_PAB < 0
)

-- ============================================================
-- FINAL OUTPUT: ATP with FG + Construct
-- ============================================================
SELECT
    -- Context columns preserved
    COALESCE(nr.client, ai.client, 'DEFAULT_CLIENT') AS client,
    COALESCE(nr.contract, ai.contract, 'DEFAULT_CONTRACT') AS contract,
    COALESCE(nr.run, ai.run, 'CURRENT_RUN') AS run,
    
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

    -- PAB LEDGER: Running balance from correlated subquery
    COALESCE(lc.Running_PAB, ai.Total_Available) AS PAB_Running_Balance,

    -- STOCKOUT DETECTION
    CASE WHEN se.Item_Number IS NOT NULL THEN 1 ELSE 0 END AS Has_Stockout,
    se.Stockout_Date AS First_Stockout_Date,
    se.Deficit_Qty AS First_Stockout_Deficit,

    -- DECIDE (risk assessment) - 5 columns
    CASE
        WHEN se.Item_Number IS NOT NULL THEN 'CRITICAL'
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
        WHEN se.Item_Number IS NOT NULL THEN 'URGENT: Stockout projected'
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 'URGENT: No inventory'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 'EXPEDITE: Low coverage'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 'MONITOR: Partial coverage'
        ELSE 'OK: Adequate coverage'
    END AS Recommendation,
    nr.Requirement_Status,

    -- FG SOURCE (PAB-style): Coalesce from demand (view 08) and inventory (view 07) sources
    COALESCE(nr.FG_Item_Number, ai.FG_Item_Number) AS FG_Item_Number,
    COALESCE(nr.FG_Description, ai.FG_Description) AS FG_Description,
    -- Construct SOURCE (PAB-style): Coalesce from demand (view 08) and inventory (view 07) sources
    COALESCE(nr.Construct, ai.Construct) AS Construct,
    
    -- Suppression flag
    CAST(CASE WHEN COALESCE(nr.Has_Suppressed, 0) = 1 OR COALESCE(ai.Has_Suppressed, 0) = 1 THEN 1 ELSE 0 END AS BIT) AS Is_Suppressed

FROM NetRequirements nr
FULL OUTER JOIN AvailableInventory ai
    ON nr.Item_Number = ai.Item_Number
    AND nr.client = ai.client
    AND nr.contract = ai.contract
    AND nr.run = ai.run
LEFT JOIN LedgerCalculation lc
    ON COALESCE(nr.Item_Number, ai.Item_Number) = lc.Item_Number
    AND COALESCE(nr.client, ai.client) = lc.client
    AND COALESCE(nr.contract, ai.contract) = lc.contract
    AND COALESCE(nr.run, ai.run) = lc.run
LEFT JOIN StockoutEvents se
    ON COALESCE(nr.Item_Number, ai.Item_Number) = se.Item_Number
    AND COALESCE(nr.client, ai.client) = se.client
    AND COALESCE(nr.contract, ai.contract) = se.contract
    AND COALESCE(nr.run, ai.run) = se.run
    AND se.Stockout_Seq = 1  -- First stockout only
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON COALESCE(nr.Item_Number, ai.Item_Number) = ci.Item_Number

WHERE COALESCE(nr.Net_Requirement_Qty, 0) > 0
   OR COALESCE(ai.Total_Available, 0) > 0;

-- ============================================================================
-- END OF VIEW 09 (PRODUCTION STABILIZED)
-- ============================================================================
