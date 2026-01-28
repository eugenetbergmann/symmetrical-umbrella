-- ============================================================================
-- VIEW 03: dbo.ETB2_Config_Active
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Active
-- ============================================================================
-- Purpose: Unified configuration layer combining lead times and pooling
-- Grain: One row per item (COALESCE logic for multi-tier hierarchy)
-- Dependencies:
--   - dbo.ETB2_Config_Lead_Times (view 01)
--   - dbo.ETB2_Config_Part_Pooling (view 02)
-- Last Updated: 2026-01-28
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
FROM dbo.ETB2_Config_Lead_Times lt WITH (NOLOCK)
FULL OUTER JOIN dbo.ETB2_Config_Part_Pooling pp WITH (NOLOCK)
    ON lt.ITEMNMBR = pp.ITEMNMBR
