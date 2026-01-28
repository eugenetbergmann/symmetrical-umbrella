-- ============================================================================
-- VIEW 02: dbo.ETB2_Config_Part_Pooling
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Part_Pooling
-- ============================================================================
-- Purpose: Pooling classification defaults for inventory strategy
-- Grain: One row per item from item master
-- Dependencies: dbo.IV00101 (Item master - external table)
-- Last Updated: 2026-01-28
-- ============================================================================

SELECT DISTINCT
    ITEMNMBR,
    'Dedicated' AS Pooling_Classification,  -- Conservative default: dedicated resources
    1.4 AS Pooling_Multiplier,              -- Dedicated multiplier per pooling strategy
    'SYSTEM_DEFAULT' AS Config_Source
FROM dbo.IV00101 WITH (NOLOCK)
WHERE ITEMNMBR IS NOT NULL
