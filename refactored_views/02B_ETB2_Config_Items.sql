-- ============================================================================
-- VIEW 02B: dbo.ETB2_Config_Items
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Items
-- ============================================================================
-- Purpose: Master item configuration from Prosenthal_Vendor_Items
-- Grain: One row per item
-- Dependencies:
--   - dbo.Prosenthal_Vendor_Items (vendor item reference)
-- Outputs:
--   - Item_Number (PK): Unique item identifier
--   - Item_Description: Primary item description
--   - UOM_Schedule: Unit of measure schedule code
--   - Purchasing_UOM: Purchasing UOM from vendor data
--   - Is_Active: Whether item is active in vendor system
-- Last Updated: 2026-01-28
-- ============================================================================

WITH VendorItems AS (
    SELECT
        [Item Number] AS Item_Number,
        ITEMDESC AS Item_Description,
        PRCHSUOM AS Purchasing_UOM,
        UOMSCHDL AS UOM_Schedule,
        Active AS Is_Active
    FROM dbo.Prosenthal_Vendor_Items WITH (NOLOCK)
    WHERE Active = 'Yes'
)

SELECT
    Item_Number,
    Item_Description,
    UOM_Schedule,
    Purchasing_UOM,
    Is_Active
FROM VendorItems;

-- ============================================================================
-- END OF VIEW 02B
-- ============================================================================
