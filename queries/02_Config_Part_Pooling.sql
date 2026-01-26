/*******************************************************************************
* View Name:    ETB2_Config_Part_Pooling
* Deploy Order: 02 of 17
* 
* Purpose:      Pooling classification defaults for inventory strategy
* Grain:        One row per item from item master
* 
* Dependencies:
*   ✓ dbo.IV00101 (Item master - external table)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Config_Part_Pooling
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Config_Part_Pooling
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT DISTINCT
    ITEMNMBR,
    'Dedicated' AS Pooling_Classification,  -- Conservative default: dedicated resources
    1.4 AS Pooling_Multiplier,              -- Dedicated multiplier per pooling strategy
    'SYSTEM_DEFAULT' AS Config_Source
FROM dbo.IV00101
WHERE ITEMNMBR IS NOT NULL

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
