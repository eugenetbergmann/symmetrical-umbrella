-- ============================================================
-- View: Rolyat_Config_Global
-- Purpose: System-wide default parameters (lowest priority)
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Global', 'V') IS NOT NULL
    DROP VIEW dbo.Rolyat_Config_Global;
GO

CREATE VIEW dbo.Rolyat_Config_Global AS
SELECT
    Config_ID,
    Config_Key,
    Config_Value,
    Data_Type,
    Description,
    Effective_Date,
    Expiry_Date,
    Created_Date,
    Modified_Date,
    Modified_By
FROM dbo.Rolyat_Config_Global_Table;
GO