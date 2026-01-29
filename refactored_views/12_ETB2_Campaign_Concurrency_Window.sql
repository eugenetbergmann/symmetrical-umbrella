-- ============================================================================
-- VIEW 12: dbo.ETB2_Campaign_Concurrency_Window
-- Deploy Order: 12 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Campaign Concurrency Window (CCW) - overlapping campaign periods
-- Grain: One row per overlapping campaign pair
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Concurrency_Window
-- ============================================================================

SELECT 
    c1.Campaign_ID AS Campaign_A,
    c2.Campaign_ID AS Campaign_B,
    c1.Item_Number,
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
    (c1.CCU + c2.CCU) / NULLIF(c1.Campaign_Duration_Days, 0) AS Concurrency_Intensity
FROM dbo.ETB2_Campaign_Normalized_Demand c1 WITH (NOLOCK)
INNER JOIN dbo.ETB2_Campaign_Normalized_Demand c2 WITH (NOLOCK) 
    ON c1.Item_Number = c2.Item_Number
    AND c1.Campaign_ID < c2.Campaign_ID
WHERE 
    c1.Peak_Period_Start <= c2.Peak_Period_End
    AND c2.Peak_Period_Start <= c1.Peak_Period_End;

-- ============================================================================
-- END OF VIEW 12
-- ============================================================================
