-- ============================================================
-- View: Rolyat_Config_Items
-- Purpose: Item-specific overrides (highest priority)
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Items', 'V') IS NOT NULL
    DROP VIEW dbo.Rolyat_Config_Items;
GO

CREATE VIEW dbo.Rolyat_Config_Items AS
SELECT
    Item_Config_ID,
    ITEMNMBR,
    Config_Key,
    Config_Value,
    Data_Type,
    Description,
    Effective_Date,
    Expiry_Date,
    Created_Date,
    Modified_Date,
    Modified_By
FROM dbo.Rolyat_Config_Items_Table;
GO