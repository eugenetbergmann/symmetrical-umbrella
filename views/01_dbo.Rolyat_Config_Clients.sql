-- ============================================================
-- View: Rolyat_Config_Clients
-- Purpose: Client-specific overrides
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Clients', 'V') IS NOT NULL
    DROP VIEW dbo.Rolyat_Config_Clients;
GO

CREATE VIEW dbo.Rolyat_Config_Clients AS
SELECT
    CAST(NULL AS INT) AS Client_Config_ID,
    CAST(NULL AS NVARCHAR(50)) AS Client_ID,
    CAST(NULL AS NVARCHAR(100)) AS Config_Key,
    CAST(NULL AS NVARCHAR(100)) AS Config_Value,
    CAST(NULL AS NVARCHAR(20)) AS Data_Type,
    CAST(NULL AS NVARCHAR(255)) AS Description,
    CAST(NULL AS DATETIME) AS Effective_Date,
    CAST(NULL AS DATETIME) AS Expiry_Date,
    CAST(NULL AS DATETIME) AS Created_Date,
    CAST(NULL AS DATETIME) AS Modified_Date,
    CAST(NULL AS NVARCHAR(50)) AS Modified_By
WHERE 1 = 0; -- Return no rows
GO