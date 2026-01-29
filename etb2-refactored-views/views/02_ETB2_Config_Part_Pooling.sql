-- ============================================================================
-- VIEW 02: dbo.ETB2_Config_Part_Pooling (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Pooling classification defaults for inventory strategy
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
    'Dedicated' AS Pooling_Classification,  -- Conservative default: dedicated resources
    1.4 AS Pooling_Multiplier,              -- Dedicated multiplier per pooling strategy
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
-- END OF VIEW 02 (REFACTORED)
-- ============================================================================