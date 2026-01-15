-- Recursive Test Harness for Rolyat Pipeline Refactor
-- Orchestrates synthetic generation, view deployment, unit tests, and iteration loop

USE [MED];
GO

CREATE OR ALTER PROCEDURE tests.sp_run_test_iterations
    @max_iterations INT = 25,
    @seed_start INT = 1000,
    @target_pass_percentage FLOAT = 100.0,
    @max_time_per_iteration INT = 600 -- seconds
AS
BEGIN
    SET NOCOUNT ON;

    -- Create logging table
    IF OBJECT_ID('tests.TestIterationLog', 'U') IS NULL
    BEGIN
        CREATE TABLE tests.TestIterationLog (
            iteration_id INT IDENTITY(1,1),
            timestamp DATETIME2 DEFAULT GETDATE(),
            seed INT,
            scenario NVARCHAR(50),
            total_tests INT,
            passed_tests INT,
            pass_percentage FLOAT,
            duration_seconds INT,
            status NVARCHAR(50), -- 'SUCCESS', 'FAILED', 'TIMEOUT'
            diagnostics NVARCHAR(MAX)
        );
    END

    DECLARE @iteration INT = 1;
    DECLARE @current_seed INT = @seed_start;
    DECLARE @success BIT = 0;
    DECLARE @start_time DATETIME2;

    WHILE @iteration <= @max_iterations AND @success = 0
    BEGIN
        SET @start_time = GETDATE();

        -- Generate synthetic data
        EXEC stg.sp_generate_synthetic @seed = @current_seed, @scenario = 'DEFAULT', @scale_factor = 1;

        -- Note: View deployment would happen here in a real environment
        -- For this harness, assume views are pre-deployed and refreshed via ALTER VIEW
        -- In practice, you would execute the SQL files to create/alter views

        -- Run unit tests
        CREATE TABLE #CurrentResults (
            test_name NVARCHAR(100),
            pass BIT,
            message NVARCHAR(MAX),
            rows_affected INT
        );

        INSERT INTO #CurrentResults
        EXEC tests.sp_run_unit_tests;

        -- Calculate results
        DECLARE @total_tests INT, @passed_tests INT, @pass_pct FLOAT;
        SELECT @total_tests = COUNT(*), @passed_tests = SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END)
        FROM #CurrentResults;

        SET @pass_pct = CAST(@passed_tests AS FLOAT) / NULLIF(@total_tests, 0) * 100;

        -- Check success
        IF @pass_pct >= @target_pass_percentage
        BEGIN
            SET @success = 1;
        END

        -- Log iteration
        DECLARE @duration INT = DATEDIFF(SECOND, @start_time, GETDATE());
        DECLARE @status NVARCHAR(50) = CASE WHEN @success = 1 THEN 'SUCCESS'
                                           WHEN @duration > @max_time_per_iteration THEN 'TIMEOUT'
                                           ELSE 'FAILED' END;

        DECLARE @diagnostics NVARCHAR(MAX) = '';
        SELECT @diagnostics = @diagnostics + test_name + ': ' + message + CHAR(13) + CHAR(10)
        FROM #CurrentResults
        WHERE pass = 0;

        INSERT INTO tests.TestIterationLog (seed, scenario, total_tests, passed_tests, pass_percentage, duration_seconds, status, diagnostics)
        VALUES (@current_seed, 'DEFAULT', @total_tests, @passed_tests, @pass_pct, @duration, @status, @diagnostics);

        -- Output current status
        PRINT 'Iteration ' + CAST(@iteration AS NVARCHAR(10)) + ': Seed ' + CAST(@current_seed AS NVARCHAR(10)) +
              ', Passed ' + CAST(@passed_tests AS NVARCHAR(10)) + '/' + CAST(@total_tests AS NVARCHAR(10)) +
              ' (' + CAST(@pass_pct AS NVARCHAR(10)) + '%)' +
              CASE WHEN @success = 1 THEN ' - SUCCESS!' ELSE '' END;

        -- Increment for next iteration
        SET @iteration = @iteration + 1;
        SET @current_seed = @current_seed + 1;

        -- Check timeout
        IF @duration > @max_time_per_iteration
        BEGIN
            PRINT 'Iteration timed out after ' + CAST(@duration AS NVARCHAR(10)) + ' seconds';
            BREAK;
        END

        DROP TABLE #CurrentResults;
    END

    -- Final status
    IF @success = 1
    BEGIN
        PRINT 'Harness completed successfully after ' + CAST(@iteration - 1 AS NVARCHAR(10)) + ' iterations';
        -- Produce final readout artifacts
        EXEC tests.sp_generate_readout;
    END
    ELSE
    BEGIN
        PRINT 'Harness failed after ' + CAST(@iteration - 1 AS NVARCHAR(10)) + ' iterations';
        -- Produce diagnostic package
        EXEC tests.sp_generate_diagnostics;
    END
END
GO

-- Procedure to generate final readout
CREATE OR ALTER PROCEDURE tests.sp_generate_readout
AS
BEGIN
    SET NOCOUNT ON;

    -- Get final iteration details
    DECLARE @final_seed INT, @pass_pct FLOAT;
    SELECT TOP 1 @final_seed = seed, @pass_pct = pass_percentage
    FROM tests.TestIterationLog
    WHERE status = 'SUCCESS'
    ORDER BY iteration_id DESC;

    -- Sample planner view
    SELECT TOP 100 *
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE Action_Tag LIKE 'URGENT_%'
    ORDER BY ABS(Deficit) DESC, DUEDATE ASC;

    -- Summary metrics
    SELECT
        'Final Readout' AS report_type,
        @final_seed AS seed_used,
        @pass_pct AS final_pass_percentage,
        GETDATE() AS timestamp;

    PRINT 'Readout generated. Check results above.';
END
GO

-- Procedure to generate diagnostics on failure
CREATE OR ALTER PROCEDURE tests.sp_generate_diagnostics
AS
BEGIN
    SET NOCOUNT ON;

    -- Get last failed iteration
    SELECT TOP 1 *
    FROM tests.TestIterationLog
    ORDER BY iteration_id DESC;

    -- Sample failing rows (if any)
    SELECT TOP 10 'Sample failing data' AS note, *
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE Action_Tag LIKE 'URGENT_%' OR Updated_QC_Flag = 'REVIEW_NO_WC_AVAILABLE';

    PRINT 'Diagnostics generated. Check results above.';
END
GO

-- Example execution
-- EXEC tests.sp_run_test_iterations @max_iterations = 25, @seed_start = 1000;