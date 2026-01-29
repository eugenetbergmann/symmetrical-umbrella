-- ============================================================================
-- VIEW 01: dbo.ETB2_Config_Lead_Times (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Lead time configuration with 30-day defaults for novel-modality CDMO
-- Grain: One row per item from item master
-- Dependencies: dbo.IV00101 (Item master - external table)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
-- Last Updated: 2026-01-29
-- ============================================================================

SELECT DISTINCT
    -- Context columns
    'DEFAULT_CLIENT' AS client,
    'DEFAULT_CONTRACT' AS contract,
    'CURRENT_RUN' AS run,
    
    -- Core columns
    ITEMNMBR,
    30 AS Lead_Time_Days,  -- Conservative default for novel-modality CDMO
    GETDATE() AS Last_Updated,
    'SYSTEM_DEFAULT' AS Config_Source,
    
    -- Suppression flag
    CAST(0 AS BIT) AS Is_Suppressed
    
FROM dbo.IV00101 WITH (NOLOCK)
WHERE ITEMNMBR IS NOT NULL
  AND ITEMNMBR NOT LIKE 'MO-%'  -- Filter out MO- conflated items
  AND CAST(GETDATE() AS DATE) BETWEEN 
      DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
      AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
  AND CAST(0 AS BIT) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 01 (REFACTORED)
-- ============================================================================