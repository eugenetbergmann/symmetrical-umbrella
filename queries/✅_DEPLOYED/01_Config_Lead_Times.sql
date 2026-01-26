/*******************************************************************************
* View Name:    ETB2_Config_Lead_Times
* Deploy Order: 01 of 17
* 
* Purpose:      Lead time configuration with 30-day defaults for novel-modality CDMO
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
* 6. Save as: dbo.ETB2_Config_Lead_Times
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Config_Lead_Times
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT DISTINCT
    ITEMNMBR,
    30 AS Lead_Time_Days,  -- Conservative default for novel-modality CDMO
    GETDATE() AS Last_Updated,
    'SYSTEM_DEFAULT' AS Config_Source
FROM dbo.IV00101
WHERE ITEMNMBR IS NOT NULL

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
