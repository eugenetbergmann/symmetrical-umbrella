/*
================================================================================
Configuration Tables: Rolyat Stock-Out Intelligence Pipeline v2.0
Description: Hierarchical configuration tables for tunable parameters
Version: 2.0.0
Last Modified: 2026-01-16

Purpose:
  - Provides centralized configuration for all tunable parameters
  - Supports hierarchy: Item-specific → ABC Class → Global defaults
  - Enables client/item-specific overrides without code changes

Tables:
  - Rolyat_Config_Global: System-wide default parameters
  - Rolyat_Config_ABC_Defaults: ABC classification defaults
  - Rolyat_Config_Items: Item-specific overrides
  - Rolyat_Config_OrderSizing: Safety stock and order sizing parameters
  - Rolyat_Config_Clients: Client-specific overrides
  - Rolyat_Site_Config: Site/location type definitions
================================================================================
*/

-- ============================================================
-- Table: Rolyat_Config_Global
-- Purpose: System-wide default parameters (lowest priority)
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Global', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_Config_Global;
GO

CREATE TABLE dbo.Rolyat_Config_Global (
    Config_ID INT IDENTITY(1,1) PRIMARY KEY,
    Config_Key NVARCHAR(100) NOT NULL UNIQUE,
    Config_Value NVARCHAR(500) NOT NULL,
    Data_Type NVARCHAR(20) NOT NULL DEFAULT 'STRING',
    Description NVARCHAR(500) NULL,
    Effective_Date DATE NOT NULL DEFAULT GETDATE(),
    Expiry_Date DATE NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER
);
GO

-- Insert global defaults
INSERT INTO dbo.Rolyat_Config_Global (Config_Key, Config_Value, Data_Type, Description) VALUES
('ActiveWindow_Past_Days', '21', 'INT', 'Days in past to include for active window demand suppression'),
('ActiveWindow_Future_Days', '21', 'INT', 'Days in future to include for active window demand suppression'),
('WFQ_Hold_Days', '14', 'INT', 'Default quarantine hold period for WFQ inventory'),
('WFQ_Expiry_Filter_Days', '30', 'INT', 'Days before expiry to exclude WFQ batches'),
('RMQTY_Hold_Days', '7', 'INT', 'Default hold period for RMQTY inventory'),
('RMQTY_Expiry_Filter_Days', '30', 'INT', 'Days before expiry to exclude RMQTY batches'),
('Degradation_Tier1_Days', '30', 'INT', 'Age threshold for Tier 1 (100% usable)'),
('Degradation_Tier1_Factor', '1.00', 'DECIMAL', 'Degradation factor for Tier 1'),
('Degradation_Tier2_Days', '60', 'INT', 'Age threshold for Tier 2 (75% usable)'),
('Degradation_Tier2_Factor', '0.75', 'DECIMAL', 'Degradation factor for Tier 2'),
('Degradation_Tier3_Days', '90', 'INT', 'Age threshold for Tier 3 (50% usable)'),
('Degradation_Tier3_Factor', '0.50', 'DECIMAL', 'Degradation factor for Tier 3'),
('Degradation_Tier4_Factor', '0.00', 'DECIMAL', 'Degradation factor for Tier 4 (obsolete)'),
('WC_Batch_Shelf_Life_Days', '90', 'INT', 'Default shelf life for WC batches'),
('BackwardSuppression_Lookback_Days', '21', 'INT', 'Days to look back for demand reconciliation'),
('BackwardSuppression_Match_Tolerance_Days', '7', 'INT', 'Tolerance days for matching planned vs actual'),
('BackwardSuppression_Extended_Lookback_Days', '60', 'INT', 'Extended lookback for GMP/PPQ long-tail processes'),
('Safety_Stock_Days', '7', 'INT', 'Default days of supply for safety stock calculation'),
('Safety_Stock_Method', 'DAYS_OF_SUPPLY', 'STRING', 'Default SS calculation method'),
('Urgent_Purchase_Threshold', '100', 'DECIMAL', 'ATP deficit threshold for URGENT_PURCHASE'),
('Urgent_Transfer_Threshold', '50', 'DECIMAL', 'ATP deficit threshold for URGENT_TRANSFER');
GO

-- ============================================================
-- Table: Rolyat_Config_ABC_Defaults
-- Purpose: ABC classification-based defaults (medium priority)
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_ABC_Defaults', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_Config_ABC_Defaults;
GO

CREATE TABLE dbo.Rolyat_Config_ABC_Defaults (
    ABC_Config_ID INT IDENTITY(1,1) PRIMARY KEY,
    ABC_Class CHAR(1) NOT NULL,
    Config_Key NVARCHAR(100) NOT NULL,
    Config_Value NVARCHAR(500) NOT NULL,
    Data_Type NVARCHAR(20) NOT NULL DEFAULT 'STRING',
    Description NVARCHAR(500) NULL,
    Effective_Date DATE NOT NULL DEFAULT GETDATE(),
    Expiry_Date DATE NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
    CONSTRAINT UQ_ABC_Config UNIQUE (ABC_Class, Config_Key)
);
GO

INSERT INTO dbo.Rolyat_Config_ABC_Defaults (ABC_Class, Config_Key, Config_Value, Data_Type, Description) VALUES
('A', 'Safety_Stock_Days', '10', 'INT', 'Higher safety stock for critical items'),
('A', 'ActiveWindow_Future_Days', '28', 'INT', 'Longer planning horizon for A items'),
('B', 'Safety_Stock_Days', '7', 'INT', 'Standard safety stock'),
('C', 'Safety_Stock_Days', '5', 'INT', 'Lower safety stock for C items'),
('X', 'Safety_Stock_Days', '14', 'INT', 'Maximum safety stock for critical items'),
('X', 'BackwardSuppression_Lookback_Days', '60', 'INT', 'Extended lookback for long PPQ tails');
GO

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

-- ============================================================
-- Table: Rolyat_Config_OrderSizing
-- Purpose: Safety stock and order sizing parameters per item
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_OrderSizing', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_Config_OrderSizing;
GO

CREATE TABLE dbo.Rolyat_Config_OrderSizing (
    OrderSizing_ID INT IDENTITY(1,1) PRIMARY KEY,
    ITEMNMBR NVARCHAR(50) NOT NULL UNIQUE,
    Safety_Stock_Qty DECIMAL(18,5) NULL,
    Safety_Stock_Days INT NULL,
    Safety_Stock_Method NVARCHAR(20) NULL,
    Z_Score DECIMAL(5,2) NULL DEFAULT 2.05,
    Demand_Std_Dev DECIMAL(18,5) NULL,
    Lead_Time_Std_Dev DECIMAL(18,5) NULL,
    Min_Order_Qty DECIMAL(18,5) NULL,
    Max_Order_Qty DECIMAL(18,5) NULL,
    Order_Multiple DECIMAL(18,5) NULL,
    Reorder_Point DECIMAL(18,5) NULL,
    Lead_Time_Days INT NULL,
    ABC_Class CHAR(1) NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER
);
GO

-- ============================================================
-- Table: Rolyat_Site_Config
-- Purpose: Site/location type definitions for WFQ/RMQTY/WC
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Site_Config', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_Site_Config;
GO

CREATE TABLE dbo.Rolyat_Site_Config (
    Site_Config_ID INT IDENTITY(1,1) PRIMARY KEY,
    LOCNCODE NVARCHAR(20) NOT NULL UNIQUE,
    Site_Type NVARCHAR(20) NOT NULL,
    Site_Description NVARCHAR(200) NULL,
    Active BIT NOT NULL DEFAULT 1,
    Hold_Days_Override INT NULL,
    Expiry_Filter_Days_Override INT NULL,
    Restricted_To_Client_ID NVARCHAR(50) NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER
);
GO

INSERT INTO dbo.Rolyat_Site_Config (LOCNCODE, Site_Type, Site_Description, Active) VALUES
('WF-Q', 'WFQ', 'Whiptail Quarantine - Incoming inspection', 1),
('WF-Q2', 'WFQ', 'Whiptail Quarantine Secondary', 1),
('RMQTY', 'RMQTY', 'Restricted Material Quantity - Reserved stock', 1),
('RMQTY-PPQ', 'RMQTY', 'RMQTY for PPQ validation batches', 1),
('WF-WC1', 'WC', 'Work Center 1 - Viral Suite A', 1),
('WF-WC2', 'WC', 'Work Center 2 - Viral Suite B', 1),
('WF-WC3', 'WC', 'Work Center 3 - Fill/Finish', 1),
('WF-REL', 'RELEASED', 'Released inventory - Available for allocation', 1),
('WF-STG', 'STAGING', 'Staging area - Pre-production', 1);
GO

-- ============================================================
-- Table: Rolyat_RMQTY_Reservations
-- Purpose: RMQTY reservation tracking for client/PPQ allocations
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_RMQTY_Reservations', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_RMQTY_Reservations;
GO

CREATE TABLE dbo.Rolyat_RMQTY_Reservations (
    Reservation_ID INT IDENTITY(1,1) PRIMARY KEY,
    ITEMNMBR NVARCHAR(50) NOT NULL,
    Batch_ID NVARCHAR(50) NOT NULL,
    Site_ID NVARCHAR(20) NOT NULL,
    Reserved_For_Client_ID NVARCHAR(50) NULL,
    Reserved_PPQ_Qty DECIMAL(18,5) NOT NULL DEFAULT 0,
    Total_Qty DECIMAL(18,5) NOT NULL,
    Allow_Sharing_Excess BIT NOT NULL DEFAULT 0,
    Sharing_Priority INT NOT NULL DEFAULT 100,
    Shareable_Qty AS (Total_Qty - Reserved_PPQ_Qty),
    Reservation_Status NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    Reservation_Date DATE NOT NULL DEFAULT GETDATE(),
    Expiry_Date DATE NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
    CONSTRAINT UQ_RMQTY_Reservation UNIQUE (ITEMNMBR, Batch_ID, Site_ID)
);
GO

-- ============================================================
-- Table: Rolyat_WC_Staging_Events
-- Purpose: Track WC staging events (irreversible commitments)
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_WC_Staging_Events', 'U') IS NOT NULL
    DROP TABLE dbo.Rolyat_WC_Staging_Events;
GO

CREATE TABLE dbo.Rolyat_WC_Staging_Events (
    Staging_Event_ID INT IDENTITY(1,1) PRIMARY KEY,
    ITEMNMBR NVARCHAR(50) NOT NULL,
    ORDERNUMBER NVARCHAR(50) NOT NULL,
    WC_ID NVARCHAR(20) NOT NULL,
    Route_ID NVARCHAR(50) NULL,
    Staged_Qty DECIMAL(18,5) NOT NULL,
    Staging_Date DATE NOT NULL,
    Expected_Consumption_Date DATE NULL,
    Source_Batch_ID NVARCHAR(50) NULL,
    Source_Site_ID NVARCHAR(20) NULL,
    Client_ID NVARCHAR(50) NOT NULL,
    Program_Phase NVARCHAR(20) NULL,
    Staging_Status NVARCHAR(20) NOT NULL DEFAULT 'STAGED',
    Consumed_Qty DECIMAL(18,5) NULL DEFAULT 0,
    Consumption_Date DATE NULL,
    Is_Matched_To_Demand BIT NOT NULL DEFAULT 0,
    Matched_Demand_ID INT NULL,
    Created_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_Date DATETIME2 NOT NULL DEFAULT GETDATE(),
    Modified_By NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER
);
GO

CREATE NONCLUSTERED INDEX IX_Rolyat_WC_Staging_Item_Order
ON dbo.Rolyat_WC_Staging_Events (ITEMNMBR, ORDERNUMBER, Staging_Status)
INCLUDE (Staged_Qty, Staging_Date, WC_ID);
GO

PRINT 'Rolyat Configuration Tables created successfully.';
GO
