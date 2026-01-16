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