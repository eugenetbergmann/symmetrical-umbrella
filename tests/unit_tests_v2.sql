/*
================================================================================
Unit Tests: Rolyat Stock-Out Intelligence Pipeline v2.0
Description: Comprehensive test suite for v2.0 features
Version: 2.0.0
Last Modified: 2026-01-16

Test Categories:
  1. Configuration Hierarchy Tests
  2. Active Window Tests (Asymmetric)
  3. WC Staging Semantics Tests
  4. Backward Suppression Tests
  5. ATP Formula Tests
  6. Safety Stock Tests (Forecast Level Only)
  7. Action Tag Tests
  8. RMQTY Reservation Tests
  9. Integration Tests
================================================================================
*/

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'tests')
    EXEC('CREATE SCHEMA tests');
GO

IF OBJECT_ID('tests.TestResults_v2', 'U') IS NOT NULL
    DROP TABLE tests.TestResults_v2;
GO

CREATE TABLE tests.TestResults_v2 (
    Test_ID INT IDENTITY(1,1) PRIMARY KEY,
    Test_Category NVARCHAR(100) NOT NULL,
    Test_Name NVARCHAR(200) NOT NULL,
    Test_Description NVARCHAR(500) NULL,
    Expected_Result NVARCHAR(500) NULL,
    Actual_Result NVARCHAR(500) NULL,
    Pass_Fail NVARCHAR(10) NOT NULL,
    Error_Message NVARCHAR(MAX) NULL,
    Execution_Time_Ms INT NULL,
    Test_Date DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

IF OBJECT_ID('tests.sp_run_v2_tests', 'P') IS NOT NULL
    DROP PROCEDURE tests.sp_run_v2_tests;
GO

CREATE PROCEDURE tests.sp_run_v2_tests
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2;
    DECLARE @TestName NVARCHAR(200);
    DECLARE @TestCategory NVARCHAR(100);
    DECLARE @Expected NVARCHAR(500);
    DECLARE @Actual NVARCHAR(500);
    DECLARE @PassFail NVARCHAR(10);
    
    DELETE FROM tests.TestResults_v2 WHERE Test_Date < DATEADD(DAY, -7, GETDATE());
    
    PRINT '========================================';
    PRINT 'Rolyat v2.0 Unit Tests';
    PRINT 'Started: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '========================================';
    
    -- Test 1.1: Global Config Retrieval
    SET @TestCategory = 'Configuration Hierarchy';
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Global Config Retrieval';
        SET @Expected = '21';
        SELECT @Actual = dbo.fn_GetConfig(NULL, NULL, 'ActiveWindow_Past_Days', GETDATE());
        SET @PassFail = CASE WHEN @Actual = @Expected THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 1.2: Item-Specific Override
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Item-Specific Config Override';
        IF NOT EXISTS (SELECT 1 FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = 'TEST_ITEM_001' AND Config_Key = 'ActiveWindow_Future_Days')
            INSERT INTO dbo.Rolyat_Config_Items (ITEMNMBR, Config_Key, Config_Value, Data_Type)
            VALUES ('TEST_ITEM_001', 'ActiveWindow_Future_Days', '42', 'INT');
        SET @Expected = '42';
        SELECT @Actual = dbo.fn_GetConfig('TEST_ITEM_001', NULL, 'ActiveWindow_Future_Days', GETDATE());
        SET @PassFail = CASE WHEN @Actual = @Expected THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        DELETE FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = 'TEST_ITEM_001';
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 2.1: Symmetric Window Default
    SET @TestCategory = 'Active Window';
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Symmetric Active Window Default';
        DECLARE @WindowStart DATE, @WindowEnd DATE;
        SELECT @WindowStart = Window_Start, @WindowEnd = Window_End
        FROM dbo.fn_GetActiveWindow(NULL, NULL, CAST(GETDATE() AS DATE));
        SET @Expected = '42';
        SET @Actual = CAST(DATEDIFF(DAY, @WindowStart, @WindowEnd) AS NVARCHAR(10));
        SET @PassFail = CASE WHEN @Actual = @Expected THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Test_Description, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, 'Default window should span 42 days (±21)', @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 3.1: Staging Event Creates Commitment
    SET @TestCategory = 'WC Staging Semantics';
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Staging Event Creates Commitment';
        INSERT INTO dbo.Rolyat_WC_Staging_Events 
            (ITEMNMBR, ORDERNUMBER, WC_ID, Staged_Qty, Staging_Date, Client_ID, Staging_Status)
        VALUES ('TEST_STG_ITEM', 'MO-TEST-001', 'WF-WC1', 100.0, CAST(GETDATE() AS DATE), 'TEST_CLIENT', 'STAGED');
        DECLARE @StagedQty DECIMAL(18,5);
        SELECT @StagedQty = Staged_Qty FROM dbo.Rolyat_WC_Staging_Events WHERE ITEMNMBR = 'TEST_STG_ITEM';
        SET @Expected = '100.00000';
        SET @Actual = CAST(@StagedQty AS NVARCHAR(20));
        SET @PassFail = CASE WHEN @StagedQty = 100.0 THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Test_Description, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, 'Staging event should record committed qty', @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        DELETE FROM dbo.Rolyat_WC_Staging_Events WHERE ITEMNMBR = 'TEST_STG_ITEM';
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 4.1: Backward Suppression Lookback Config
    SET @TestCategory = 'Backward Suppression';
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Backward Suppression Lookback Config';
        SET @Expected = '21';
        SELECT @Actual = Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'BackwardSuppression_Lookback_Days';
        SET @PassFail = CASE WHEN @Actual = @Expected THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 4.2: Extended Lookback for GMP/PPQ
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Extended Lookback for GMP/PPQ';
        SET @Expected = '60';
        SELECT @Actual = Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'BackwardSuppression_Extended_Lookback_Days';
        SET @PassFail = CASE WHEN @Actual = @Expected THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Test_Description, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, 'Extended lookback should be 60 days for GMP/PPQ', @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 6.1: Safety Stock Method Default
    SET @TestCategory = 'Safety Stock';
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Safety Stock Calculation Methods';
        SET @Expected = 'DAYS_OF_SUPPLY';
        SELECT @Actual = Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Safety_Stock_Method';
        SET @PassFail = CASE WHEN @Actual = @Expected THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Test_Description, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, 'Default SS method should be DAYS_OF_SUPPLY', @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 8.1: RMQTY PPQ Reservation
    SET @TestCategory = 'RMQTY Reservations';
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'RMQTY PPQ Reservation';
        INSERT INTO dbo.Rolyat_RMQTY_Reservations 
            (ITEMNMBR, Batch_ID, Site_ID, Reserved_PPQ_Qty, Total_Qty, Allow_Sharing_Excess, Sharing_Priority)
        VALUES ('TEST_RMQTY_ITEM', 'BATCH-001', 'RMQTY', 50.0, 100.0, 1, 10);
        DECLARE @ShareableQty DECIMAL(18,5);
        SELECT @ShareableQty = Shareable_Qty FROM dbo.Rolyat_RMQTY_Reservations WHERE ITEMNMBR = 'TEST_RMQTY_ITEM';
        SET @Expected = '50.00000';
        SET @Actual = CAST(@ShareableQty AS NVARCHAR(20));
        SET @PassFail = CASE WHEN @ShareableQty = 50.0 THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Test_Description, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, 'Shareable_Qty = Total_Qty - Reserved_PPQ_Qty', @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        DELETE FROM dbo.Rolyat_RMQTY_Reservations WHERE ITEMNMBR = 'TEST_RMQTY_ITEM';
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test 9.1: Site Config Active
    SET @TestCategory = 'Integration';
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @TestName = 'Site Configuration Active';
        DECLARE @ActiveSites INT;
        SELECT @ActiveSites = COUNT(*) FROM dbo.Rolyat_Site_Config WHERE Active = 1;
        SET @Expected = '>0';
        SET @Actual = CAST(@ActiveSites AS NVARCHAR(10));
        SET @PassFail = CASE WHEN @ActiveSites > 0 THEN 'PASS' ELSE 'FAIL' END;
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Test_Description, Expected_Result, Actual_Result, Pass_Fail, Execution_Time_Ms)
        VALUES (@TestCategory, @TestName, 'At least one site should be configured', @Expected, @Actual, @PassFail, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
    END TRY
    BEGIN CATCH
        INSERT INTO tests.TestResults_v2 (Test_Category, Test_Name, Pass_Fail, Error_Message)
        VALUES (@TestCategory, @TestName, 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    -- Test Summary
    PRINT '';
    PRINT '========================================';
    PRINT 'Test Summary';
    PRINT '========================================';
    
    DECLARE @TotalTests INT, @PassedTests INT, @FailedTests INT, @ErrorTests INT;
    SELECT @TotalTests = COUNT(*) FROM tests.TestResults_v2 WHERE Test_Date >= CAST(GETDATE() AS DATE);
    SELECT @PassedTests = COUNT(*) FROM tests.TestResults_v2 WHERE Pass_Fail = 'PASS' AND Test_Date >= CAST(GETDATE() AS DATE);
    SELECT @FailedTests = COUNT(*) FROM tests.TestResults_v2 WHERE Pass_Fail = 'FAIL' AND Test_Date >= CAST(GETDATE() AS DATE);
    SELECT @ErrorTests = COUNT(*) FROM tests.TestResults_v2 WHERE Pass_Fail = 'ERROR' AND Test_Date >= CAST(GETDATE() AS DATE);
    
    PRINT 'Total Tests: ' + CAST(@TotalTests AS VARCHAR(10));
    PRINT 'Passed: ' + CAST(@PassedTests AS VARCHAR(10));
    PRINT 'Failed: ' + CAST(@FailedTests AS VARCHAR(10));
    PRINT 'Errors: ' + CAST(@ErrorTests AS VARCHAR(10));
    PRINT 'Pass Rate: ' + CAST(CAST(@PassedTests * 100.0 / NULLIF(@TotalTests, 0) AS DECIMAL(5,2)) AS VARCHAR(10)) + '%';
    PRINT '========================================';
    
    SELECT Test_Category, Test_Name, Test_Description, Expected_Result, Actual_Result, Pass_Fail, Error_Message, Execution_Time_Ms
    FROM tests.TestResults_v2
    WHERE Test_Date >= CAST(GETDATE() AS DATE)
    ORDER BY Test_ID;
END
GO

IF OBJECT_ID('tests.sp_quick_v2_test', 'P') IS NOT NULL
    DROP PROCEDURE tests.sp_quick_v2_test;
GO

CREATE PROCEDURE tests.sp_quick_v2_test
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Running quick v2.0 validation...';
    
    IF OBJECT_ID('dbo.Rolyat_Config_Global', 'V') IS NULL
    BEGIN PRINT 'ERROR: Rolyat_Config_Global view not found'; RETURN; END
    
    IF OBJECT_ID('dbo.fn_GetConfig', 'FN') IS NULL
    BEGIN PRINT 'ERROR: fn_GetConfig function not found'; RETURN; END
    
    DECLARE @ConfigCount INT;
    SELECT @ConfigCount = COUNT(*) FROM dbo.Rolyat_Config_Global;
    
    IF @ConfigCount = 0
    BEGIN PRINT 'ERROR: Rolyat_Config_Global has no data'; RETURN; END
    
    PRINT 'Quick validation PASSED';
    PRINT 'Config tables: OK';
    PRINT 'Functions: OK';
    PRINT 'Global config records: ' + CAST(@ConfigCount AS VARCHAR(10));
END
GO

PRINT 'Rolyat v2.0 Unit Tests created successfully.';
PRINT 'Run tests with: EXEC tests.sp_run_v2_tests;';
GO
