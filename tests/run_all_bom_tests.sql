-- Master Script for BOM Tests
-- Validates end-to-end sequence integrity, violations, reconstruction correctness

USE [MED];
GO

CREATE OR ALTER PROCEDURE tests.sp_run_bom_tests
AS
BEGIN
    SET NOCOUNT ON;

    -- Create temp table for results
    CREATE TABLE #BOMTestResults (
        test_name NVARCHAR(100),
        pass BIT,
        message NVARCHAR(MAX),
        rows_affected INT
    );

    -- Test 1: Event Sequence Validation
    DECLARE @seq_violations INT;
    SELECT @seq_violations = COUNT(*) FROM dbo.BOM_Event_Sequence_Validation;

    INSERT INTO #BOMTestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_bom_event_sequence',
        CASE WHEN @seq_violations = 0 THEN 1 ELSE 0 END,
        CASE WHEN @seq_violations = 0 THEN 'Event sequences are valid' ELSE 'Found ' + CAST(@seq_violations AS NVARCHAR(10)) + ' sequence violations' END,
        @seq_violations
    );

    -- Test 2: Material Balance Test
    DECLARE @balance_violations INT;
    SELECT @balance_violations = COUNT(*) FROM dbo.BOM_Material_Balance_Test WHERE Status = 'Mismatch';

    INSERT INTO #BOMTestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_bom_material_balance',
        CASE WHEN @balance_violations = 0 THEN 1 ELSE 0 END,
        CASE WHEN @balance_violations = 0 THEN 'Material balances are correct' ELSE 'Found ' + CAST(@balance_violations AS NVARCHAR(10)) + ' balance mismatches' END,
        @balance_violations
    );

    -- Test 3: Historical Reconstruction
    DECLARE @recon_violations INT;
    SELECT @recon_violations = COUNT(*) FROM dbo.Historical_Reconstruction_BOM WHERE Reconstruction_Status = 'Mismatch';

    INSERT INTO #BOMTestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_bom_historical_reconstruction',
        CASE WHEN @recon_violations = 0 THEN 1 ELSE 0 END,
        CASE WHEN @recon_violations = 0 THEN 'Historical reconstructions are accurate' ELSE 'Found ' + CAST(@recon_violations AS NVARCHAR(10)) + ' reconstruction mismatches' END,
        @recon_violations
    );

    -- Coverage Metric
    DECLARE @total_tests INT = 3;
    DECLARE @passed_tests INT;
    SELECT @passed_tests = COUNT(*) FROM #BOMTestResults WHERE pass = 1;

    INSERT INTO #BOMTestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_bom_coverage',
        CASE WHEN @passed_tests = @total_tests THEN 1 ELSE 0 END,
        CAST(@passed_tests AS NVARCHAR(10)) + '/' + CAST(@total_tests AS NVARCHAR(10)) + ' BOM tests passed',
        @passed_tests
    );

    -- Return results
    SELECT * FROM #BOMTestResults ORDER BY test_name;

    -- Summary
    SELECT
        COUNT(*) AS total_bom_tests,
        SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS passed_bom_tests,
        CAST(SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS pass_percentage
    FROM #BOMTestResults;

    DROP TABLE #BOMTestResults;
END
GO