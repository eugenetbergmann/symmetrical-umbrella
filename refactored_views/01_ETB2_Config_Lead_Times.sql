-- ============================================================================
-- VIEW 01: dbo.ETB2_Config_Lead_Times
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Lead_Times
-- ============================================================================
-- Purpose: Lead time configuration with 30-day defaults for novel-modality CDMO
-- Grain: One row per item from item master
-- Dependencies: dbo.IV00101 (Item master - external table)
-- Last Updated: 2026-01-28
-- ============================================================================

SELECT DISTINCT
    ITEMNMBR,
    30 AS Lead_Time_Days,  -- Conservative default for novel-modality CDMO
    GETDATE() AS Last_Updated,
    'SYSTEM_DEFAULT' AS Config_Source
FROM dbo.IV00101 WITH (NOLOCK)
WHERE ITEMNMBR IS NOT NULL
