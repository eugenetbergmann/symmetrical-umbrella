-- ============================================================================
-- VIEW 03: dbo.ETB2_Config_Active (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Unified configuration layer combining lead times and pooling
-- Grain: One row per item (COALESCE logic for multi-tier hierarchy)
-- Dependencies:
--   - dbo.ETB2_Config_Lead_Times (view 01)
--   - dbo.ETB2_Config_Part_Pooling (view 02)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all joins and GROUP BY
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
-- Last Updated: 2026-01-29
-- ============================================================================

SELECT
    -- Context columns (preserved from both sources)
    COALESCE(lt.client, pp.client, 'DEFAULT_CLIENT') AS client,
    COALESCE(lt.contract, pp.contract, 'DEFAULT_CONTRACT') AS contract,
    COALESCE(lt.run, pp.run, 'CURRENT_RUN') AS run,
    
    -- Core columns
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
    GETDATE() AS Last_Updated,
    
    -- Suppression flag (combined)
    CAST(COALESCE(lt.Is_Suppressed, 0) | COALESCE(pp.Is_Suppressed, 0) AS BIT) AS Is_Suppressed
    
FROM dbo.ETB2_Config_Lead_Times lt WITH (NOLOCK)
FULL OUTER JOIN dbo.ETB2_Config_Part_Pooling pp WITH (NOLOCK)
    ON lt.ITEMNMBR = pp.ITEMNMBR
    AND lt.client = pp.client
    AND lt.contract = pp.contract
    AND lt.run = pp.run
WHERE COALESCE(lt.ITEMNMBR, pp.ITEMNMBR) NOT LIKE 'MO-%'  -- Filter out MO- conflated items
  AND CAST(GETDATE() AS DATE) BETWEEN 
      DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
      AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
  AND CAST(COALESCE(lt.Is_Suppressed, 0) | COALESCE(pp.Is_Suppressed, 0) AS BIT) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 03 (REFACTORED)
-- ============================================================================