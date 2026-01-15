-- Unit Tests for Rolyat Pipeline Refactor
-- Returns test results for each assertion

USE [MED];
GO

CREATE OR ALTER PROCEDURE tests.sp_run_unit_tests
AS
BEGIN
    SET NOCOUNT ON;

    -- Create temp table for results
    CREATE TABLE #TestResults (
        test_name NVARCHAR(100),
        pass BIT,
        message NVARCHAR(MAX),
        rows_affected INT
    );

    -- Test 1: Adjusted Running Balance Identity
    DECLARE @mismatches INT;
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE Adjusted_Running_Balance <> ISNULL(LAG(Adjusted_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, SortPriority, ORDERNUMBER), 0)
        + CASE WHEN item_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
        + CASE WHEN item_row_num = 1 THEN COALESCE(POs, 0.0) ELSE 0.0 END
        - effective_demand;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_adjusted_running_balance_identity',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All balances match identity' ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' mismatches' END,
        @mismatches
    );

    -- Test 2: SortPriority Presence
    DECLARE @null_sort INT;
    SELECT @null_sort = COUNT(*) FROM dbo.Rolyat_Cleaned_Base_Demand_1 WHERE SortPriority IS NULL;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_sortpriority_presence',
        CASE WHEN @null_sort = 0 THEN 1 ELSE 0 END,
        CASE WHEN @null_sort = 0 THEN 'No NULL SortPriority' ELSE 'Found ' + CAST(@null_sort AS NVARCHAR(10)) + ' NULL values' END,
        @null_sort
    );

    -- Test 3: Active Window Flagging
    DECLARE @window_mismatch INT;
    SELECT @window_mismatch = COUNT(*)
    FROM dbo.Rolyat_Cleaned_Base_Demand_1
    WHERE (DUEDATE BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE()) AND IsActiveWindow <> 1)
       OR (DUEDATE NOT BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE()) AND IsActiveWindow <> 0);

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_active_window_flagging',
        CASE WHEN @window_mismatch = 0 THEN 1 ELSE 0 END,
        CASE WHEN @window_mismatch = 0 THEN 'Active window flags correct' ELSE 'Found ' + CAST(@window_mismatch AS NVARCHAR(10)) + ' mismatches' END,
        @window_mismatch
    );

    -- Test 4: WC Allocation Status Rules
    DECLARE @status_error INT;
    SELECT @status_error = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE Row_Type = 'DEMAND_EVENT'
      AND Adjusted_Running_Balance > 0
      AND NOT (wc_allocation_status = 'Full_Allocation' AND QC_Flag = 'NORMAL');

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_wc_allocation_legends',
        CASE WHEN @status_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @status_error = 0 THEN 'Allocation status rules correct' ELSE 'Found ' + CAST(@status_error AS NVARCHAR(10)) + ' status errors' END,
        @status_error
    );

    -- Test 5: QC Review Condition
    DECLARE @qc_error INT;
    SELECT @qc_error = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE (Adjusted_Running_Balance < 0 AND Alternate_Stock <= 0 AND Updated_QC_Flag <> 'REVIEW_NO_WC_AVAILABLE')
       OR (NOT (Adjusted_Running_Balance < 0 AND Alternate_Stock <= 0) AND Updated_QC_Flag = 'REVIEW_NO_WC_AVAILABLE');

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_qc_review_condition',
        CASE WHEN @qc_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @qc_error = 0 THEN 'QC review conditions correct' ELSE 'Found ' + CAST(@qc_error AS NVARCHAR(10)) + ' QC errors' END,
        @qc_error
    );

    -- Test 6: WFQ RMQTY Integration
    DECLARE @alt_stock_error INT;
    SELECT @alt_stock_error = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE WFQ_QTY + RMQTY_QTY <> Alternate_Stock;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_wfq_rmqty_integration',
        CASE WHEN @alt_stock_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @alt_stock_error = 0 THEN 'Alternate stock computed correctly' ELSE 'Found ' + CAST(@alt_stock_error AS NVARCHAR(10)) + ' computation errors' END,
        @alt_stock_error
    );

    -- Test 7: StockOut Action Tags
    DECLARE @action_error INT;
    SELECT @action_error = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE Deficit > 0
      AND Action_Tag NOT IN ('URGENT_EXPEDITE', 'URGENT_TRANSFER', 'URGENT_PURCHASE', 'REVIEW_ALTERNATE_STOCK', 'STOCK_OUT');

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_stockout_action_tags',
        CASE WHEN @action_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @action_error = 0 THEN 'Action tags consistent with rules' ELSE 'Found ' + CAST(@action_error AS NVARCHAR(10)) + ' invalid tags' END,
        @action_error
    );

    -- Test 8: Example Item Snapshot (10.020B)
    DECLARE @example_error INT;
    SELECT @example_error = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE ITEMNMBR = '10.020B'
      AND NOT (
          -- Same-day PO offsets negative drift: expect positive or zero balance after PO
          (Row_Type = 'PURCHASE_ORDER' AND Adjusted_Running_Balance >= 0)
          OR (Row_Type <> 'PURCHASE_ORDER')
      );

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_example_item_snapshot',
        CASE WHEN @example_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @example_error = 0 THEN 'Example item 10.020B shows expected behavior' ELSE 'Example item does not match expected snapshot' END,
        @example_error
    );

    -- Test 9: Noise Reduction
    DECLARE @review_count INT;
    SELECT @review_count = COUNT(*) FROM dbo.Rolyat_StockOut_Analysis_v2 WHERE Updated_QC_Flag = 'REVIEW_NO_WC_AVAILABLE';

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_noise_reduction',
        CASE WHEN @review_count <= 3 THEN 1 ELSE 0 END, -- Threshold for synthetic data
        'REVIEW_NO_WC_AVAILABLE count: ' + CAST(@review_count AS NVARCHAR(10)) + ' (target <= 3)',
        @review_count
    );

    -- Test 10: Coverage Metric
    DECLARE @total_tests INT = 9; -- Number of tests above
    DECLARE @passed_tests INT;
    SELECT @passed_tests = COUNT(*) FROM #TestResults WHERE pass = 1;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_coverage_metric',
        CASE WHEN @passed_tests = @total_tests THEN 1 ELSE 0 END,
        CAST(@passed_tests AS NVARCHAR(10)) + '/' + CAST(@total_tests AS NVARCHAR(10)) + ' tests passed (' + CAST(CAST(@passed_tests AS FLOAT) / @total_tests * 100 AS NVARCHAR(10)) + '%)',
        @passed_tests
    );

    -- Return results
    SELECT * FROM #TestResults ORDER BY test_name;

    -- Summary
    SELECT
        COUNT(*) AS total_tests,
        SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS passed_tests,
        CAST(SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS pass_percentage
    FROM #TestResults;

    DROP TABLE #TestResults;
END
GO