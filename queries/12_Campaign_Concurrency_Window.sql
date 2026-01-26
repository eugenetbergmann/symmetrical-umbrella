/*******************************************************************************
* View Name:    ETB2_Campaign_Concurrency_Window
* Deploy Order: 12 of 17
* 
* Purpose:      Campaign Concurrency Window (CCW) - overlapping campaign periods
* Grain:        One row per campaign pair per item
* 
* Dependencies:
*   ✓ dbo.ETB2_Campaign_Normalized_Demand (view 11)
*   ✓ dbo.ETB2_Config_Active (view 03)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Campaign_Concurrency_Window
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Campaign_Concurrency_Window
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    a.Campaign_ID,
    b.Campaign_ID AS Overlapping_Campaign,
    a.ITEMNMBR,
    -- Calculate overlap in days
    DATEDIFF(DAY, 
        CASE WHEN a.Peak_Period_Start < b.Peak_Period_Start THEN a.Peak_Period_Start ELSE b.Peak_Period_Start END,
        CASE WHEN a.Peak_Period_End > b.Peak_Period_End THEN a.Peak_Period_End ELSE b.Peak_Period_End END
    ) AS CCW,  -- Campaign Concurrency Window in days
    -- Overlap boundaries
    CASE WHEN a.Peak_Period_Start < b.Peak_Period_Start THEN a.Peak_Period_Start ELSE b.Peak_Period_Start END AS Overlap_Start,
    CASE WHEN a.Peak_Period_End > b.Peak_Period_End THEN a.Peak_Period_End ELSE b.Peak_Period_End END AS Overlap_End,
    -- Default CCW = 1 (conservative, due to missing campaign dates in source data)
    1 AS Default_CCW,
    CASE 
        WHEN DATEDIFF(DAY, 
            CASE WHEN a.Peak_Period_Start < b.Peak_Period_Start THEN a.Peak_Period_Start ELSE b.Peak_Period_Start END,
            CASE WHEN a.Peak_Period_End > b.Peak_Period_End THEN a.Peak_Period_End ELSE b.Peak_Period_End END
        ) > 0 THEN 'OVERLAPS'
        ELSE 'SEPARATE'
    END AS Concurrency_Status
FROM dbo.ETB2_Campaign_Normalized_Demand a
INNER JOIN dbo.ETB2_Campaign_Normalized_Demand b ON a.ITEMNMBR = b.ITEMNMBR
WHERE a.Campaign_ID <> b.Campaign_ID
    AND a.Campaign_ID < b.Campaign_ID  -- Prevent duplicate pairs (A-B and B-A)

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
