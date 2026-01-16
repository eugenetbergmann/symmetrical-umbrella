-- ============================================================
-- Table: Rolyat_Config_Clients
-- Purpose: Client-specific overrides
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Clients', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_Config_Clients;
GO

CREATE TABLE dbo.Rolyat_Config_Clients (
    Client_Config_ID INT IDENTITY(1,1) PRIMARY KEY,
    Client_ID NVARCHAR(50) NOT NULL,
    Config_Key NVARCHAR(100) NOT NULL,
    Config_Value NVARCHAR(500) NOT NULL,
    Data_Type NVARCHAR(20) NOT NULL DEFAULT 'STRING',
    Description NVARCHAR(500) NULL,
    Effective_Date DATE NOT NULL DEFAULT GETDATE(),
    Expiry_Date DATE NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
    CONSTRAINT UQ_Client_Config UNIQUE (Client_ID, Config_Key)
);
GO