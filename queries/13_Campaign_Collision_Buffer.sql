/*******************************************************************************
* View Name:    ETB2_Campaign_Collision_Buffer
* Deploy Order: 13 of 17
* 
* Purpose:      Collision buffer quantity = CCU × CCW × Pooling Multiplier
* Grain:        One row per campaign per item
* 
* Dependencies:
*   ✓ dbo.ETB2_Campaign_Normalized_Demand (view 11)
*   ✓ dbo.ETB2_Campaign_Concurrency_Window (view 12)
*   ✓ dbo.ETB2_Config_Part_Pooling (view 02)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Campaign_Collision_Buffer
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Campaign_Collision_Buffer
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    n.ITEMNMBR,
    n.Campaign_ID,
    n.CCU,
    COALESCE(w.CCW, 1) AS CCW,  -- Default to 1 if no overlap data
    -- Pooling multiplier based on classification
    CASE p.Pooling_Classification
        WHEN 'Pooled' THEN 1.5
        WHEN 'Mixed' THEN 1.2
        ELSE 1.0  -- Dedicated = 1.0
    END AS Pooling_Multiplier,
    -- Collision buffer formula: CCU × CCW × Pooling_Multiplier
    n.CCU * COALESCE(w.CCW, 1) * 
        CASE p.Pooling_Classification
            WHEN 'Pooled' THEN 1.5
            WHEN 'Mixed' THEN 1.2
            ELSE 1.0
        END AS collision_buffer_qty,
    -- Breakdown for transparency
    n.CCU * COALESCE(w.CCW, 1) AS Base_Buffer,
    n.CCU * COALESCE(w.CCW, 1) * 
        CASE p.Pooling_Classification
            WHEN 'Pooled' THEN 1.5
            WHEN 'Mixed' THEN 1.2
            ELSE 1.0
        END - (n.CCU * COALESCE(w.CCW, 1)) AS Pooling_Adjustment
FROM dbo.ETB2_Campaign_Normalized_Demand n
LEFT JOIN dbo.ETB2_Campaign_Concurrency_Window w ON n.Campaign_ID = w.Campaign_ID
LEFT JOIN dbo.ETB2_Config_Part_Pooling p ON n.ITEMNMBR = p.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
