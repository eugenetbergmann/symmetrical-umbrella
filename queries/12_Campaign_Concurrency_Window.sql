/*******************************************************************************
 * View Name:    ETB2_Campaign_Concurrency_Window
 * Deploy Order: 12 of 17
 * Status:       🔴 NOT YET DEPLOYED
 * 
 * Purpose:      Campaign Concurrency Window (CCW) - overlapping campaign periods
 * Grain:        One row per overlapping campaign pair
 * 
 * Dependencies (MUST exist - verify first):
 *   ✅ ETB2_Config_Lead_Times (deployed)
 *   ✅ ETB2_Config_Part_Pooling (deployed)
 *   ✅ ETB2_Config_Active (deployed)
 *   ✅ dbo.ETB2_Campaign_Normalized_Demand (view 11 - deploy first)
 *
 * ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
 * 1. Object Explorer → Right-click "Views" → "New View..."
 * 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
 * 3. Delete default SQL
 * 4. Copy SELECT below (between markers)
 * 5. Paste into SQL pane
 * 6. Execute (!) to test
 * 7. Save as: dbo.ETB2_Campaign_Concurrency_Window
 * 8. Refresh Views folder
 *
 * Validation: 
 *   SELECT COUNT(*) FROM dbo.ETB2_Campaign_Concurrency_Window
 *   Expected: Overlapping campaign pairs
 *******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    c1.Campaign_ID AS Campaign_A,
    c2.Campaign_ID AS Campaign_B,
    -- Concurrency window calculation
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
    -- Overlap duration
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
    -- Combined CCU during overlap
    c1.CCU + c2.CCU AS Combined_CCU,
    -- Concurrency ratio with NULLIF to prevent division by zero
    (c1.CCU + c2.CCU) / NULLIF(c1.Campaign_Duration_Days, 0) AS Concurrency_Intensity
FROM dbo.ETB2_Campaign_Normalized_Demand c1 WITH (NOLOCK)
INNER JOIN dbo.ETB2_Campaign_Normalized_Demand c2 WITH (NOLOCK) 
    ON c1.ITEMNMBR = c2.ITEMNMBR
    AND c1.Campaign_ID < c2.Campaign_ID  -- Avoid duplicates
WHERE 
    -- Only consider overlapping periods (inclusive boundaries)
    c1.Peak_Period_Start <= c2.Peak_Period_End
    AND c2.Peak_Period_Start <= c1.Peak_Period_End

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Concurrency summary:
   SELECT COUNT(*) AS Overlapping_Pairs FROM dbo.ETB2_Campaign_Concurrency_Window

2. Longest concurrency windows:
   SELECT TOP 10
       Campaign_A,
       Campaign_B,
       Concurrency_Days,
       Combined_CCU
   FROM dbo.ETB2_Campaign_Concurrency_Window
   ORDER BY Concurrency_Days DESC

3. Intensity analysis:
   SELECT 
       AVG(Concurrency_Intensity) AS Avg_Intensity,
       MAX(Concurrency_Intensity) AS Max_Intensity
   FROM dbo.ETB2_Campaign_Concurrency_Window
*/
