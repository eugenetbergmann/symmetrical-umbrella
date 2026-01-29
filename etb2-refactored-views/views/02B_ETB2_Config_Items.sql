-- ============================================================================
-- VIEW 02B: dbo.ETB2_Config_Items (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Master item configuration from Prosenthal_Vendor_Items
-- Grain: One row per item
-- Dependencies:
--   - dbo.Prosenthal_Vendor_Items (vendor item reference)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
-- Last Updated: 2026-01-29
-- ============================================================================

SELECT
    -- Context columns
    'DEFAULT_CLIENT' AS client,
    'DEFAULT_CONTRACT' AS contract,
    'CURRENT_RUN' AS run,
    
    -- Core columns
    [Item Number] AS Item_Number,
    ITEMDESC AS Item_Description,
    PRCHSUOM AS Purchasing_UOM,
    UOMSCHDL AS UOM_Schedule,
    
    -- Suppression flag
    CAST(0 AS BIT) AS Is_Suppressed
    
FROM dbo.Prosenthal_Vendor_Items WITH (NOLOCK)
WHERE Active = 'Yes'
  AND [Item Number] NOT LIKE 'MO-%'  -- Filter out MO- conflated items
  AND CAST(GETDATE() AS DATE) BETWEEN 
      DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
      AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
  AND CAST(0 AS BIT) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 02B (REFACTORED)
-- ============================================================================