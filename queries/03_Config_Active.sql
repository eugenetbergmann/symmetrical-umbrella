/*******************************************************************************
* View Name:    ETB2_Config_Active
* Deploy Order: 03 of 17
* 
* Purpose:      Unified configuration layer combining lead times and pooling
* Grain:        One row per item (COALESCE logic for multi-tier hierarchy)
* 
* Dependencies:
*   ✓ dbo.ETB2_Config_Lead_Times (view 01)
*   ✓ dbo.ETB2_Config_Part_Pooling (view 02)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Config_Active
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Config_Active
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    COALESCE(lt.ITEMNMBR, pp.ITEMNMBR) AS ITEMNMBR,
    COALESCE(lt.Lead_Time_Days, 30) AS Lead_Time_Days,
    COALESCE(pp.Pooling_Classification, 'Dedicated') AS Pooling_Classification,
    COALESCE(pp.Pooling_Multiplier, 1.4) AS Pooling_Multiplier,
    CASE 
        WHEN lt.ITEMNMBR IS NOT NULL AND pp.ITEMNMBR IS NOT NULL THEN 'Both_Configured'
        WHEN lt.ITEMNMBR IS NOT NULL THEN 'Lead_Time_Only'
        WHEN pp.ITEMNMBR IS NOT NULL THEN 'Pooling_Only'
        ELSE 'Default'
    END AS Config_Status,
    GETDATE() AS Last_Updated
FROM dbo.ETB2_Config_Lead_Times lt
FULL OUTER JOIN dbo.ETB2_Config_Part_Pooling pp ON lt.ITEMNMBR = pp.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
