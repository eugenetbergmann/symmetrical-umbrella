-- ============================================================
-- Table: Rolyat_Config_Items
-- Purpose: Item-specific overrides (highest priority)
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Items', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_Config_Items;
GO

CREATE TABLE dbo.Rolyat_Config_Items (
    Item_Config_ID INT IDENTITY(1,1) PRIMARY KEY,
    ITEMNMBR NVARCHAR(50) NOT NULL,
    Config_Key NVARCHAR(100) NOT NULL,
    Config_Value NVARCHAR(500) NOT NULL,
    Data_Type NVARCHAR(20) NOT NULL DEFAULT 'STRING',
    Description NVARCHAR(500) NULL,
    Effective_Date DATE NOT NULL DEFAULT GETDATE(),
    Expiry_Date DATE NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
    CONSTRAINT UQ_Item_Config UNIQUE (ITEMNMBR, Config_Key)
);
GO

CREATE NONCLUSTERED INDEX IX_Rolyat_Config_Items_Lookup
ON dbo.Rolyat_Config_Items (ITEMNMBR, Config_Key)
INCLUDE (Config_Value, Data_Type, Effective_Date, Expiry_Date);
GO