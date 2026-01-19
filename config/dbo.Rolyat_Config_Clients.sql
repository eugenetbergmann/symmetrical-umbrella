-- ============================================================
-- View: Rolyat_Config_Clients
-- Purpose: Client-specific overrides
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Clients', 'V') IS NOT NULL
    DROP VIEW dbo.Rolyat_Config_Clients;
GO

CREATE VIEW dbo.Rolyat_Config_Clients AS
SELECT
    Client_Config_ID,
    Client_ID,
    Config_Key,
    Config_Value,
    Data_Type,
    Description,
    Effective_Date,
    Expiry_Date,
    Created_Date,
    Modified_Date,
    Modified_By
FROM dbo.Rolyat_Config_Clients_Table;
GO