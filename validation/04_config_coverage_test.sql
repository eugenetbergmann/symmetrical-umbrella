/*
===============================================================================
Config Coverage Test: Rolyat Stock-Out Intelligence Pipeline v2.0
Description: Validation of configuration framework completeness
Version: 2.0.0
Last Modified: 2026-01-16

Purpose:
  - Verify all required config tables exist
  - Test fn_GetConfig function for hierarchical lookup
  - Check coverage of key parameters across items/clients
  - Ensure no missing defaults

Execution:
  - Run to validate configuration setup
  - Critical for tunable parameter functionality
===============================================================================
*/

-- Check 1: Config tables existence
PRINT 'Checking config table existence...';

IF OBJECT_ID('dbo.Rolyat_Config_Global', 'V') IS NULL
    PRINT 'FAIL: Rolyat_Config_Global view missing'
ELSE
    PRINT 'PASS: Rolyat_Config_Global exists'

IF OBJECT_ID('dbo.Rolyat_Config_Clients', 'V') IS NULL
    PRINT 'FAIL: Rolyat_Config_Clients view missing'
ELSE
    PRINT 'PASS: Rolyat_Config_Clients exists'

IF OBJECT_ID('dbo.Rolyat_Config_Items', 'V') IS NULL
    PRINT 'FAIL: Rolyat_Config_Items view missing'
ELSE
    PRINT 'PASS: Rolyat_Config_Items exists'

-- Check 2: fn_GetConfig function
PRINT 'Testing fn_GetConfig function...';

IF OBJECT_ID('dbo.fn_GetConfig', 'FN') IS NULL
    PRINT 'FAIL: fn_GetConfig function missing'
ELSE
BEGIN
    -- Test global default
    DECLARE @test_value NVARCHAR(500) = dbo.fn_GetConfig('ActiveWindow_Past_Days', NULL, NULL, GETDATE());
    IF @test_value IS NOT NULL
        PRINT 'PASS: fn_GetConfig returns global default: ' + @test_value
    ELSE
        PRINT 'FAIL: fn_GetConfig failed to return global default'

    -- Test with sample item (assuming exists)
    SET @test_value = dbo.fn_GetConfig('Safety_Stock_Days', 'SAMPLE_ITEM', NULL, GETDATE());
    PRINT 'INFO: fn_GetConfig for item returned: ' + ISNULL(@test_value, 'NULL')
END

-- Check 3: Required global keys coverage
PRINT 'Checking required global config keys...';

SELECT Config_Key, Config_Value
FROM dbo.Rolyat_Config_Global
WHERE Config_Key IN (
    'ActiveWindow_Past_Days',
    'ActiveWindow_Future_Days',
    'WFQ_Hold_Days',
    'RMQTY_Hold_Days',
    'Degradation_Tier1_Days',
    'Safety_Stock_Days'
)
ORDER BY Config_Key;

-- Check 4: Config coverage statistics
PRINT 'Config coverage statistics...';

SELECT 'Global Keys' AS Config_Level, COUNT(*) AS Key_Count FROM dbo.Rolyat_Config_Global
UNION ALL
SELECT 'Client Overrides', COUNT(*) FROM dbo.Rolyat_Config_Clients
UNION ALL
SELECT 'Item Overrides', COUNT(*) FROM dbo.Rolyat_Config_Items;

PRINT 'Config coverage test completed.';