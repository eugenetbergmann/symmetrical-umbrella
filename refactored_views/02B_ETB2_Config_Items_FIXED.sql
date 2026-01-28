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
-- Purpose: Master item configuration combining IV00101 + Prosenthal_Vendor_Items
-- Grain: One row per item
-- Dependencies:
--   - dbo.IV00101 (Dynamics GP item master)
--   - dbo.Prosenthal_Vendor_Items (vendor item reference)
-- Outputs:
--   - Item_Number (PK): Unique item identifier
--   - Item_Description: Primary item description (master or vendor)
--   - UOM_Schedule: Unit of measure schedule code
--   - Purchasing_UOM: Placeholder for future PO planning
--   - Config_Source: Indicates data source (Both, Master, Vendor)
--   - Is_Active: Whether item is active in vendor system
-- Last Updated: 2026-01-28
-- ============================================================================

WITH ItemMaster AS (
    SELECT
        ITEMNMBR AS Item_Number,
        ITEMDESC AS Item_Description,
        UOMSCHDL AS UOM_Schedule,
        'TBD_PRCHSUOM' AS Purchasing_UOM
    FROM dbo.IV00101 WITH (NOLOCK)
),

VendorDetails AS (
    SELECT
        [Item Number] AS Item_Number,
        [Item Description] AS Vendor_Item_Description,
        UOMSCHDL AS Vendor_UOM_Schedule,
        Active AS Is_Active,
        ROW_NUMBER() OVER (
            PARTITION BY [Item Number] 
            ORDER BY [Item Description] DESC
        ) AS RowNum
    FROM dbo.Prosenthal_Vendor_Items WITH (NOLOCK)
)

SELECT
    COALESCE(im.Item_Number, vd.Item_Number) AS Item_Number,
    COALESCE(im.Item_Description, vd.Vendor_Item_Description) AS Item_Description,
    COALESCE(im.UOM_Schedule, vd.Vendor_UOM_Schedule, 'UNKNOWN') AS UOM_Schedule,
    im.Purchasing_UOM,
    CASE 
        WHEN im.Item_Number IS NOT NULL AND vd.Item_Number IS NOT NULL THEN 'Both_Sources'
        WHEN im.Item_Number IS NOT NULL THEN 'Master_Only'
        WHEN vd.Item_Number IS NOT NULL THEN 'Vendor_Only'
        ELSE 'Unknown'
    END AS Config_Source,
    COALESCE(vd.Is_Active, 'Yes') AS Is_Active
FROM ItemMaster im
FULL OUTER JOIN VendorDetails vd 
    ON im.Item_Number = vd.Item_Number
WHERE vd.RowNum = 1 OR vd.RowNum IS NULL;

-- ============================================================================
-- END OF VIEW 02B
-- ============================================================================
