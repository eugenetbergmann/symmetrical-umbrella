-- ============================================================
-- View: Rolyat_Config_Global
-- Purpose: System-wide default parameters (lowest priority)
-- ============================================================
IF OBJECT_ID('dbo.Rolyat_Config_Global', 'V') IS NOT NULL
    DROP VIEW dbo.Rolyat_Config_Global;
GO

CREATE VIEW dbo.Rolyat_Config_Global AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY Config_Key) AS INT) AS Config_ID,
    Config_Key,
    Config_Value,
    'NVARCHAR' AS Data_Type,
    'Default configuration value' AS Description,
    '1900-01-01' AS Effective_Date,
    NULL AS Expiry_Date,
    GETDATE() AS Created_Date,
    GETDATE() AS Modified_Date,
    'SYSTEM' AS Modified_By
FROM (
    VALUES
        ('Degradation_Tier1_Days', '30'),
        ('Degradation_Tier1_Factor', '1.00'),
        ('Degradation_Tier2_Days', '60'),
        ('Degradation_Tier2_Factor', '0.75'),
        ('Degradation_Tier3_Days', '90'),
        ('Degradation_Tier3_Factor', '0.50'),
        ('Degradation_Tier4_Factor', '0.00'),
        ('WFQ_Hold_Days', '14'),
        ('WFQ_Expiry_Filter_Days', '90'),
        ('RMQTY_Hold_Days', '7'),
        ('RMQTY_Expiry_Filter_Days', '90'),
        ('WC_Batch_Shelf_Life_Days', '180'),
        ('ActiveWindow_Past_Days', '21'),
        ('ActiveWindow_Future_Days', '21'),
        ('BackwardSuppression_Lookback_Days', '21'),
        ('BackwardSuppression_Extended_Lookback_Days', '60'),
        ('Safety_Stock_Method', 'DAYS_OF_SUPPLY'),
        ('Safety_Stock_Days', '0')
) AS Configs(Config_Key, Config_Value);
GO