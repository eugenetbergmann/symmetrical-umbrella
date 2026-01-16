/*
================================================================================
Recursive Test Harness for Rolyat Pipeline
Description: Orchestrates synthetic generation, view deployment, and test iterations
Version: 2.0.0
Last Modified: 2026-01-16

Features:
  - Iterative testing with configurable seed progression
  - Automatic synthetic data generation per iteration
  - Comprehensive logging and diagnostics
  - Success/failure reporting with detailed metrics
================================================================================
*/

USE [MED];
GO

-- Create tests schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'tests')
BEGIN
    EXEC('CREATE SCHEMA tests');
END
GO

-- ============================================================
-- Test Iteration Log Table
-- ============================================================
IF OBJECT_ID('tests.TestIterationLog', 'U') IS NULL
BEGIN
    CREATE TABLE tests.TestIterationLog (
        iteration_id INT IDENTITY(1,1) PRIMARY KEY,
        timestamp DATETIME2 DEFAULT GETDATE(),
        seed INT NOT NULL,
        scenario NVARCHAR(50) NOT NULL,
        total_tests INT,
        passed_tests INT,
        failed_tests INT,
        pass_percentage FLOAT,
        duration_seconds INT,
        status NVARCHAR(50), -- 'SUCCESS', 'FAILED', 'TIMEOUT', 'ERROR'
        diagnostics NVARCHAR(MAX),
        created_at DATETIME2 DEFAULT GETDATE()
    );
    
    CREATE INDEX IX_TestIterationLog_Status ON tests.TestIterationLog(status);
    CREATE INDEX IX_TestIterationLog_Timestamp ON tests.TestIterationLog(timestamp);
END
GO

-- ============================================================
-- Main Test Harness Procedure
-- ============================================================
CREATE OR ALTER PROCEDURE tests.sp_run_test_iterations
    @max_iterations INT = 25,
    @seed_start INT = 1000,
    @target_pass_percentage FLOAT = 100.0,
    @max_time_per_iteration INT = 600, -- seconds
    @scenario NVARCHAR(50) = 'DEFAULT',
    @verbose BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @iteration INT = 1;
    DECLARE @current_seed INT = @seed_start;
    DECLARE @success BIT = 0;
    DECLARE @start_time DATETIME2;
    DECLARE @iteration_start DATETIME2;
    DECLARE @harness_start DATETIME2 = GETDATE();

    -- ============================================================
    -- Main Iteration Loop
    -- ============================================================
    WHILE @iteration <= @max_iterations AND @success = 0
    BEGIN
        SET @iteration_start = GETDATE();

        BEGIN TRY
            -- Generate synthetic data for this iteration
            IF @verbose = 1
                PRINT 'Iteration ' + CAST(@iteration AS NVARCHAR(10)) + ': Generating synthetic data with seed ' + CAST(@current_seed AS NVARCHAR(10));
            
            EXEC stg.sp_generate_synthetic 
                @seed = @current_seed, 
                @scenario = @scenario, 
                @scale_factor = 1;

            -- Run unit tests
            CREATE TABLE #CurrentResults (
                test_id INT,
                test_category NVARCHAR(50),
                test_name NVARCHAR(100),
                result NVARCHAR(10),
                message NVARCHAR(MAX),
                rows_affected INT,
                execution_time_ms INT
            );

            INSERT INTO #CurrentResults
            EXEC tests.sp_run_unit_tests;

            -- Calculate results
            DECLARE @total_tests INT, @passed_tests INT, @failed_tests INT, @pass_pct FLOAT;
            
            SELECT 
                @total_tests = COUNT(*), 
                @passed_tests = SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END),
                @failed_tests = SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END)
            FROM #CurrentResults
            WHERE test_category <> 'Coverage';

            SET @pass_pct = CAST(@passed_tests AS FLOAT) / NULLIF(@total_tests, 0) * 100;

            -- Check success
            IF @pass_pct >= @target_pass_percentage
            BEGIN
                SET @success = 1;
            END

            -- Calculate duration
            DECLARE @duration INT = DATEDIFF(SECOND, @iteration_start, GETDATE());
            
            -- Determine status
            DECLARE @status NVARCHAR(50) = CASE 
                WHEN @success = 1 THEN 'SUCCESS'
                WHEN @duration > @max_time_per_iteration THEN 'TIMEOUT'
                ELSE 'FAILED' 
            END;

            -- Build diagnostics for failed tests
            DECLARE @diagnostics NVARCHAR(MAX) = '';
            SELECT @diagnostics = @diagnostics + test_name + ': ' + message + CHAR(13) + CHAR(10)
            FROM #CurrentResults
            WHERE result = 'FAIL';

            -- Add ATP vs Forecast mismatch diagnostics
            DECLARE @atp_forecast_mismatch INT = 0;
            SELECT @atp_forecast_mismatch = COUNT(*)
            FROM dbo.Rolyat_Final_Ledger_3
            WHERE Forecast_Running_Balance >= 0 AND ATP_Running_Balance < 0;

            IF @atp_forecast_mismatch > 0
            BEGIN
                SET @diagnostics = @diagnostics + 'ATP vs Forecast mismatch rows: ' + CAST(@atp_forecast_mismatch AS NVARCHAR(10)) + CHAR(13) + CHAR(10);
            END

            -- Log iteration
            INSERT INTO tests.TestIterationLog (
                seed, scenario, total_tests, passed_tests, failed_tests, 
                pass_percentage, duration_seconds, status, diagnostics
            )
            VALUES (
                @current_seed, @scenario, @total_tests, @passed_tests, @failed_tests,
                @pass_pct, @duration, @status, @diagnostics
            );

            -- Output current status
            IF @verbose = 1
            BEGIN
                PRINT 'Iteration ' + CAST(@iteration AS NVARCHAR(10)) + 
                      ': Seed ' + CAST(@current_seed AS NVARCHAR(10)) +
                      ', Passed ' + CAST(@passed_tests AS NVARCHAR(10)) + '/' + CAST(@total_tests AS NVARCHAR(10)) +
                      ' (' + CAST(ROUND(@pass_pct, 2) AS NVARCHAR(10)) + '%)' +
                      CASE WHEN @success = 1 THEN ' - SUCCESS!' ELSE '' END;
            END

            -- Check timeout
            IF @duration > @max_time_per_iteration
            BEGIN
                PRINT 'Iteration timed out after ' + CAST(@duration AS NVARCHAR(10)) + ' seconds';
                DROP TABLE #CurrentResults;
                BREAK;
            END

            DROP TABLE #CurrentResults;

        END TRY
        BEGIN CATCH
            -- Log error
            INSERT INTO tests.TestIterationLog (
                seed, scenario, total_tests, passed_tests, failed_tests,
                pass_percentage, duration_seconds, status, diagnostics
            )
            VALUES (
                @current_seed, @scenario, 0, 0, 0, 0,
                DATEDIFF(SECOND, @iteration_start, GETDATE()),
                'ERROR',
                'Error: ' + ERROR_MESSAGE()
            );

            IF @verbose = 1
                PRINT 'Iteration ' + CAST(@iteration AS NVARCHAR(10)) + ' ERROR: ' + ERROR_MESSAGE();

            IF OBJECT_ID('tempdb..#CurrentResults') IS NOT NULL
                DROP TABLE #CurrentResults;
        END CATCH

        -- Increment for next iteration
        SET @iteration = @iteration + 1;
        SET @current_seed = @current_seed + 1;
    END

    -- ============================================================
    -- Final Status and Reporting
    -- ============================================================
    DECLARE @total_duration INT = DATEDIFF(SECOND, @harness_start, GETDATE());

    IF @success = 1
    BEGIN
        PRINT '';
        PRINT '============================================================';
        PRINT 'HARNESS COMPLETED SUCCESSFULLY';
        PRINT 'Iterations: ' + CAST(@iteration - 1 AS NVARCHAR(10));
        PRINT 'Total Duration: ' + CAST(@total_duration AS NVARCHAR(10)) + ' seconds';
        PRINT '============================================================';
        
        -- Generate final readout
        EXEC tests.sp_generate_readout;
    END
    ELSE
    BEGIN
        PRINT '';
        PRINT '============================================================';
        PRINT 'HARNESS FAILED';
        PRINT 'Iterations: ' + CAST(@iteration - 1 AS NVARCHAR(10));
        PRINT 'Total Duration: ' + CAST(@total_duration AS NVARCHAR(10)) + ' seconds';
        PRINT '============================================================';
        
        -- Generate diagnostics
        EXEC tests.sp_generate_diagnostics;
    END

    -- Return summary
    SELECT
        CASE WHEN @success = 1 THEN 'SUCCESS' ELSE 'FAILED' END AS harness_status,
        @iteration - 1 AS iterations_run,
        @total_duration AS total_duration_seconds,
        @target_pass_percentage AS target_pass_percentage;
END
GO

-- ============================================================
-- Readout Generation Procedure
-- ============================================================
CREATE OR ALTER PROCEDURE tests.sp_generate_readout
AS
BEGIN
    SET NOCOUNT ON;

    -- Get final successful iteration details
    DECLARE @final_seed INT, @pass_pct FLOAT, @final_timestamp DATETIME2;
    
    SELECT TOP 1 
        @final_seed = seed, 
        @pass_pct = pass_percentage,
        @final_timestamp = timestamp
    FROM tests.TestIterationLog
    WHERE status = 'SUCCESS'
    ORDER BY iteration_id DESC;

    PRINT '';
    PRINT '============================================================';
    PRINT 'FINAL READOUT';
    PRINT '============================================================';
    PRINT 'Seed Used: ' + CAST(@final_seed AS NVARCHAR(10));
    PRINT 'Pass Percentage: ' + CAST(@pass_pct AS NVARCHAR(10)) + '%';
    PRINT 'Timestamp: ' + CONVERT(NVARCHAR(30), @final_timestamp, 120);
    PRINT '============================================================';

    -- Sample urgent items for planner review
    PRINT '';
    PRINT 'Top 20 Urgent Items:';
    SELECT TOP 20 
        ITEMNMBR,
        Client_ID,
        DUEDATE,
        Action_Tag,
        Deficit_ATP,
        Alternate_Stock
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE Action_Tag LIKE 'URGENT_%'
    ORDER BY Deficit_ATP DESC, DUEDATE ASC;

    -- Summary metrics
    SELECT
        'Final Readout' AS report_type,
        @final_seed AS seed_used,
        @pass_pct AS final_pass_percentage,
        @final_timestamp AS timestamp,
        (SELECT COUNT(*) FROM dbo.Rolyat_Final_Ledger_3 WHERE Stock_Out_Flag = 1) AS total_stockout_rows,
        (SELECT COUNT(DISTINCT ITEMNMBR) FROM dbo.Rolyat_StockOut_Analysis_v2 WHERE Action_Tag LIKE 'URGENT_%') AS urgent_items_count;
END
GO

-- ============================================================
-- Diagnostics Generation Procedure
-- ============================================================
CREATE OR ALTER PROCEDURE tests.sp_generate_diagnostics
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '';
    PRINT '============================================================';
    PRINT 'DIAGNOSTICS REPORT';
    PRINT '============================================================';

    -- Get last iteration details
    SELECT TOP 1 
        iteration_id,
        seed,
        scenario,
        total_tests,
        passed_tests,
        failed_tests,
        pass_percentage,
        duration_seconds,
        status,
        diagnostics
    FROM tests.TestIterationLog
    ORDER BY iteration_id DESC;

    -- Iteration history
    PRINT '';
    PRINT 'Recent Iteration History:';
    SELECT TOP 10
        iteration_id,
        seed,
        pass_percentage,
        status,
        duration_seconds
    FROM tests.TestIterationLog
    ORDER BY iteration_id DESC;

    -- Sample failing data
    PRINT '';
    PRINT 'Sample Problem Data:';
    SELECT TOP 10 
        'Problem Data' AS note, 
        ITEMNMBR,
        Client_ID,
        Action_Tag,
        Updated_QC_Flag,
        Deficit_ATP
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE Action_Tag LIKE 'URGENT_%' 
       OR Updated_QC_Flag = 'REVIEW_NO_WC_AVAILABLE';

    -- Balance anomalies
    PRINT '';
    PRINT 'Balance Anomalies:';
    SELECT TOP 10
        ITEMNMBR,
        Date_Expiry,
        ATP_Running_Balance,
        Forecast_Running_Balance,
        Stock_Out_Flag
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE ATP_Running_Balance < 0 AND Forecast_Running_Balance >= 0;
END
GO

-- ============================================================
-- Quick Test Procedure (single iteration)
-- ============================================================
CREATE OR ALTER PROCEDURE tests.sp_quick_test
    @seed INT = 1000,
    @scenario NVARCHAR(50) = 'DEFAULT'
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Running quick test with seed ' + CAST(@seed AS NVARCHAR(10));

    -- Generate synthetic data
    EXEC stg.sp_generate_synthetic @seed = @seed, @scenario = @scenario, @scale_factor = 1;

    -- Run unit tests
    EXEC tests.sp_run_unit_tests;
END
GO

-- Add extended properties
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Main test harness procedure for iterative testing with synthetic data generation.',
    @level0type = N'SCHEMA', @level0name = 'tests',
    @level1type = N'PROCEDURE', @level1name = 'sp_run_test_iterations'
GO

PRINT '============================================================';
PRINT 'Test Harness Installation Complete';
PRINT '============================================================';
PRINT '';
PRINT 'Usage:';
PRINT '  -- Run full harness (up to 25 iterations)';
PRINT '  EXEC tests.sp_run_test_iterations @max_iterations = 25, @seed_start = 1000;';
PRINT '';
PRINT '  -- Run quick single test';
PRINT '  EXEC tests.sp_quick_test @seed = 1000;';
PRINT '';
PRINT '  -- Run unit tests only (no synthetic data)';
PRINT '  EXEC tests.sp_run_unit_tests;';
PRINT '============================================================';
GO
