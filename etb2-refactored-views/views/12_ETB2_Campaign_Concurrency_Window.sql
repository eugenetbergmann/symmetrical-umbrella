-- ============================================================================
-- VIEW 12: dbo.ETB2_Campaign_Concurrency_Window (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Campaign Concurrency Window (CCW) - overlapping campaign periods
-- Grain: One row per overlapping campaign pair
-- Dependencies:
--   - dbo.ETB2_Campaign_Normalized_Demand (view 11)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct carried from campaign A (same item)
--   - Is_Suppressed flag
-- Last Updated: 2026-01-30
-- ============================================================================

SELECT 
    -- Context columns preserved
    c1.client,
    c1.contract,
    c1.run,
    
    c1.Campaign_ID AS Campaign_A,
    c2.Campaign_ID AS Campaign_B,
    c1.item_number,
    c1.customer_number,
    CASE 
        WHEN c1.Peak_Period_Start > c2.Peak_Period_Start 
        THEN c1.Peak_Period_Start 
        ELSE c2.Peak_Period_Start 
    END AS Concurrency_Start,
    CASE 
        WHEN c1.Peak_Period_End < c2.Peak_Period_End 
        THEN c1.Peak_Period_End 
        ELSE c2.Peak_Period_End 
    END AS Concurrency_End,
    CASE 
        WHEN c1.Peak_Period_Start > c2.Peak_Period_Start 
             AND c1.Peak_Period_Start < c2.Peak_Period_End
        THEN DATEDIFF(DAY, c1.Peak_Period_Start, c2.Peak_Period_End)
        WHEN c2.Peak_Period_Start > c1.Peak_Period_Start 
             AND c2.Peak_Period_Start < c1.Peak_Period_End
        THEN DATEDIFF(DAY, c2.Peak_Period_Start, c1.Peak_Period_End)
        WHEN c1.Peak_Period_Start <= c2.Peak_Period_Start 
             AND c1.Peak_Period_End >= c2.Peak_Period_End
        THEN DATEDIFF(DAY, c2.Peak_Period_Start, c2.Peak_Period_End)
        WHEN c2.Peak_Period_Start <= c1.Peak_Period_Start 
             AND c2.Peak_Period_End >= c1.Peak_Period_End
        THEN DATEDIFF(DAY, c1.Peak_Period_Start, c1.Peak_Period_End)
        ELSE 0
    END AS Concurrency_Days,
    c1.CCU + c2.CCU AS Combined_CCU,
    (c1.CCU + c2.CCU) / NULLIF(c1.Campaign_Duration_Days, 0) AS Concurrency_Intensity,
    
    -- FG SOURCE (PAB-style): Carry from campaign A (same item)
    c1.FG_Item_Number,
    c1.FG_Description,
    -- Construct SOURCE (PAB-style): Carry from campaign A (same item)
    c1.Construct,
    
    -- Suppression flag (combined)
    CAST(c1.Is_Suppressed | c2.Is_Suppressed AS BIT) AS Is_Suppressed
    
FROM dbo.ETB2_Campaign_Normalized_Demand c1 WITH (NOLOCK)
INNER JOIN dbo.ETB2_Campaign_Normalized_Demand c2 WITH (NOLOCK) 
    ON c1.item_number = c2.item_number
    AND c1.customer_number = c2.customer_number
    AND c1.client = c2.client
    AND c1.contract = c2.contract
    AND c1.run = c2.run
    AND c1.Campaign_ID < c2.Campaign_ID
WHERE 
    c1.Peak_Period_Start <= c2.Peak_Period_End
    AND c2.Peak_Period_Start <= c1.Peak_Period_End
    AND c1.Item_Number NOT LIKE 'MO-%'
    AND CAST(c1.Is_Suppressed | c2.Is_Suppressed AS BIT) = 0;

-- ============================================================================
-- END OF VIEW 12 (CONSOLIDATED FINAL)
-- ============================================================================
