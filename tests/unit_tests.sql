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

    -- Test 10: WC Demand Deprecation - Within Window with WC Not Suppressed
    DECLARE @wc_demand_within INT;
    SELECT @wc_demand_within = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE DATEDIFF(DAY, GETDATE(), Date_Expiry) BETWEEN -21 AND 21
      AND WC_Batch_ID IS NOT NULL
      AND effective_demand = Base_Demand;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_wc_demand_deprecation_within_window',
        CASE WHEN @wc_demand_within = 0 THEN 1 ELSE 0 END,
        CASE WHEN @wc_demand_within = 0 THEN 'No demands within window with WC inventory left unsuppressed' ELSE 'Found ' + CAST(@wc_demand_within AS NVARCHAR(10)) + ' unsuppressed demands within window' END,
        @wc_demand_within
    );

    -- Test 11: WC Demand Deprecation - Outside Window Incorrectly Suppressed
    DECLARE @wc_demand_outside INT;
    SELECT @wc_demand_outside = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE DATEDIFF(DAY, GETDATE(), Date_Expiry) NOT BETWEEN -21 AND 21
      AND effective_demand < Base_Demand;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_wc_demand_deprecation_outside_window',
        CASE WHEN @wc_demand_outside = 0 THEN 1 ELSE 0 END,
        CASE WHEN @wc_demand_outside = 0 THEN 'No demands outside window incorrectly suppressed' ELSE 'Found ' + CAST(@wc_demand_outside AS NVARCHAR(10)) + ' suppressed demands outside window' END,
        @wc_demand_outside
    );

    -- Test 12: Active Planning Window - Suppression Outside ±21 Days
    DECLARE @window_status_error INT;
    SELECT @window_status_error = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE DATEDIFF(DAY, GETDATE(), Date_Expiry) NOT BETWEEN -21 AND 21
      AND wc_allocation_status != 'Outside_Active_Window';

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_active_planning_window_suppression',
        CASE WHEN @window_status_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @window_status_error = 0 THEN 'Allocation status correct for out-of-window demands' ELSE 'Found ' + CAST(@window_status_error AS NVARCHAR(10)) + ' incorrect status for out-of-window demands' END,
        @window_status_error
    );

    -- Test 13: Inventory Age & Degradation - Incorrect Degradation Factors
    DECLARE @degradation_error INT;
    SELECT @degradation_error = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE WC_Degradation_Factor NOT IN (
        CASE
            WHEN DATEDIFF(DAY, GETDATE(), Date_Expiry) BETWEEN 0 AND 30 THEN 1.00
            WHEN DATEDIFF(DAY, GETDATE(), Date_Expiry) BETWEEN 31 AND 60 THEN 0.75
            WHEN DATEDIFF(DAY, GETDATE(), Date_Expiry) BETWEEN 61 AND 90 THEN 0.50
            WHEN DATEDIFF(DAY, GETDATE(), Date_Expiry) > 90 THEN 0.00
            ELSE NULL -- For negative days or other cases
        END
    ) AND WC_Degradation_Factor IS NOT NULL;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_inventory_degradation_factors',
        CASE WHEN @degradation_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @degradation_error = 0 THEN 'Degradation factors match age rules' ELSE 'Found ' + CAST(@degradation_error AS NVARCHAR(10)) + ' incorrect degradation factors' END,
        @degradation_error
    );

    -- Test 14: No Double Allocation - Allocated Exceeds Batch Effective Qty
    DECLARE @double_alloc INT;
    SELECT @double_alloc = COUNT(DISTINCT WC_Batch_ID)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    GROUP BY WC_Batch_ID
    HAVING SUM(allocated) > MAX(WC_Effective_Qty);

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_no_double_allocation',
        CASE WHEN @double_alloc = 0 THEN 1 ELSE 0 END,
        CASE WHEN @double_alloc = 0 THEN 'No over-allocated batches' ELSE 'Found ' + CAST(@double_alloc AS NVARCHAR(10)) + ' over-allocated batches' END,
        @double_alloc
    );

    -- Test 15: Running Balance - Non-Monotonic Changes
    DECLARE @balance_error INT;
    SELECT @balance_error = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE Adjusted_Running_Balance > ISNULL(LAG(Adjusted_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, SortPriority, ORDERNUMBER), 0);

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_running_balance_monotonic',
        CASE WHEN @balance_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @balance_error = 0 THEN 'Balances decrease or stay same over time' ELSE 'Found ' + CAST(@balance_error AS NVARCHAR(10)) + ' non-monotonic balance changes' END,
        @balance_error
    );

    -- Test 16: Intelligence - Invalid Stock-Out Signals
    DECLARE @intelligence_error INT;
    SELECT @intelligence_error = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3 rfl
    INNER JOIN dbo.Rolyat_WFQ_5 rwf ON rfl.ITEMNMBR = rwf.ITEMNMBR
    WHERE rfl.Row_Type = 'DEMAND_EVENT'
      AND rfl.Adjusted_Running_Balance < 0
      AND rwf.QTY_ON_HAND > 0;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_intelligence_stock_out_signals',
        CASE WHEN @intelligence_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @intelligence_error = 0 THEN 'No invalid stock-out signals' ELSE 'Found ' + CAST(@intelligence_error AS NVARCHAR(10)) + ' invalid stock-out signals' END,
        @intelligence_error
    );

    -- Test 17: Coverage Metric
    DECLARE @total_tests INT = 16; -- Number of tests above
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