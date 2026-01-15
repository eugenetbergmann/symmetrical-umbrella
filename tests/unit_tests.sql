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

    -- Test 1: Forecast Running Balance Identity
    DECLARE @mismatches INT;
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE Forecast_Running_Balance <> ISNULL(LAG(Forecast_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, SortPriority, ORDERNUMBER), 0)
        + Forecast_Supply_Event
        - Base_Demand;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_forecast_running_balance_identity',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All balances match identity' ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' mismatches' END,
        @mismatches
    );

    -- Test 2: ATP Running Balance Identity
    DECLARE @atp_mismatches INT;
    SELECT @atp_mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE ATP_Running_Balance <> ISNULL(LAG(ATP_Running_Balance) OVER (PARTITION BY ITEMNMBR, Client_ID ORDER BY Date_Expiry, SortPriority, ORDERNUMBER), 0)
        + ATP_Supply_Event
        - Effective_Demand;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_atp_running_balance_identity',
        CASE WHEN @atp_mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @atp_mismatches = 0 THEN 'All ATP balances match identity' ELSE 'Found ' + CAST(@atp_mismatches AS NVARCHAR(10)) + ' mismatches' END,
        @atp_mismatches
    );

    -- Test 3: SortPriority Presence
    DECLARE @null_sort INT;
    SELECT @null_sort = COUNT(*) FROM dbo.Rolyat_Cleaned_Base_Demand_1 WHERE SortPriority IS NULL;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_sortpriority_presence',
        CASE WHEN @null_sort = 0 THEN 1 ELSE 0 END,
        CASE WHEN @null_sort = 0 THEN 'No NULL SortPriority' ELSE 'Found ' + CAST(@null_sort AS NVARCHAR(10)) + ' NULL values' END,
        @null_sort
    );

    -- Test 4: Active Window Flagging
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

    -- Test 5: ATP Suppression Within Window
    DECLARE @atp_suppress_error INT;
    SELECT @atp_suppress_error = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE IsActiveWindow = 1
      AND effective_demand > (Base_Demand - allocated);

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_atp_suppression_within_window',
        CASE WHEN @atp_suppress_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @atp_suppress_error = 0 THEN 'ATP suppression within window correct' ELSE 'Found ' + CAST(@atp_suppress_error AS NVARCHAR(10)) + ' suppression errors' END,
        @atp_suppress_error
    );

    -- Test 6: No Suppression Outside Window
    DECLARE @outside_suppress INT;
    SELECT @outside_suppress = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE IsActiveWindow = 0
      AND effective_demand <> Base_Demand;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_no_suppression_outside_window',
        CASE WHEN @outside_suppress = 0 THEN 1 ELSE 0 END,
        CASE WHEN @outside_suppress = 0 THEN 'No suppression outside window' ELSE 'Found ' + CAST(@outside_suppress AS NVARCHAR(10)) + ' suppressed rows outside window' END,
        @outside_suppress
    );

    -- Test 7: RMQTY Client Restriction
    DECLARE @rmqty_client_error INT;
    SELECT @rmqty_client_error = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE RMQTY_QTY > 0
      AND Client_ID <> RMQTY_Client_ID
      AND RMQTY_Eligible_Qty <> 0;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_rmqty_client_restriction',
        CASE WHEN @rmqty_client_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @rmqty_client_error = 0 THEN 'RMQTY restriction respected' ELSE 'Found ' + CAST(@rmqty_client_error AS NVARCHAR(10)) + ' RMQTY client mismatches' END,
        @rmqty_client_error
    );

    -- Test 8: PO Release Logic
    DECLARE @po_release_error INT;
    SELECT @po_release_error = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE POs > 0
      AND COALESCE(MRP_IssueDate, DUEDATE) > CAST(GETDATE() AS DATE)
      AND Released_PO_Qty <> 0;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_po_release_logic',
        CASE WHEN @po_release_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @po_release_error = 0 THEN 'PO release logic correct' ELSE 'Found ' + CAST(@po_release_error AS NVARCHAR(10)) + ' release errors' END,
        @po_release_error
    );

    -- Test 9: Forecast Supply Event Composition
    DECLARE @forecast_supply_error INT;
    SELECT @forecast_supply_error = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE Forecast_Supply_Event <>
        (CASE WHEN item_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
         + CASE WHEN item_row_num = 1 THEN COALESCE(POs, 0.0) ELSE 0.0 END
         + CASE WHEN item_row_num = 1 THEN COALESCE(WFQ_QTY, 0.0) ELSE 0.0 END
         + CASE WHEN item_row_num = 1 THEN COALESCE(RMQTY_QTY, 0.0) ELSE 0.0 END);

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_forecast_supply_event',
        CASE WHEN @forecast_supply_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @forecast_supply_error = 0 THEN 'Forecast supply matches components' ELSE 'Found ' + CAST(@forecast_supply_error AS NVARCHAR(10)) + ' mismatches' END,
        @forecast_supply_error
    );

    -- Test 10: ATP Supply Event Composition
    DECLARE @atp_supply_error INT;
    SELECT @atp_supply_error = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE ATP_Supply_Event <>
        (CASE WHEN client_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
         + CASE WHEN client_row_num = 1 THEN COALESCE(Released_PO_Qty, 0.0) ELSE 0.0 END
         + CASE WHEN client_row_num = 1 THEN COALESCE(RMQTY_Eligible_Qty, 0.0) ELSE 0.0 END);

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_atp_supply_event',
        CASE WHEN @atp_supply_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @atp_supply_error = 0 THEN 'ATP supply matches components' ELSE 'Found ' + CAST(@atp_supply_error AS NVARCHAR(10)) + ' mismatches' END,
        @atp_supply_error
    );

    -- Test 11: No Double Allocation - Allocated Exceeds Batch Effective Qty
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

    -- Test 12: Inventory Age & Degradation - Incorrect Degradation Factors
    DECLARE @degradation_error INT;
    SELECT @degradation_error = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE WC_Degradation_Factor NOT IN (
        CASE
            WHEN WC_Age_Days <= 30 THEN 1.00
            WHEN WC_Age_Days <= 60 THEN 0.75
            WHEN WC_Age_Days <= 90 THEN 0.50
            ELSE 0.00
        END
    ) AND WC_Degradation_Factor IS NOT NULL;

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_inventory_degradation_factors',
        CASE WHEN @degradation_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @degradation_error = 0 THEN 'Degradation factors match age rules' ELSE 'Found ' + CAST(@degradation_error AS NVARCHAR(10)) + ' incorrect degradation factors' END,
        @degradation_error
    );

    -- Test 13: StockOut Action Tags
    DECLARE @action_error INT;
    SELECT @action_error = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE Deficit_ATP > 0
      AND Action_Tag NOT IN ('ATP_CONSTRAINED', 'URGENT_EXPEDITE', 'URGENT_TRANSFER', 'URGENT_PURCHASE', 'REVIEW_ALTERNATE_STOCK', 'STOCK_OUT');

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_stockout_action_tags',
        CASE WHEN @action_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @action_error = 0 THEN 'Action tags consistent with rules' ELSE 'Found ' + CAST(@action_error AS NVARCHAR(10)) + ' invalid tags' END,
        @action_error
    );

    -- Test 14: QC Review Condition
    DECLARE @qc_error INT;
    SELECT @qc_error = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE (ATP_Running_Balance < 0 AND Alternate_Stock <= 0 AND Updated_QC_Flag <> 'REVIEW_NO_WC_AVAILABLE')
       OR (NOT (ATP_Running_Balance < 0 AND Alternate_Stock <= 0) AND Updated_QC_Flag = 'REVIEW_NO_WC_AVAILABLE');

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_qc_review_condition',
        CASE WHEN @qc_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @qc_error = 0 THEN 'QC review conditions correct' ELSE 'Found ' + CAST(@qc_error AS NVARCHAR(10)) + ' QC errors' END,
        @qc_error
    );

    -- Test 15: Example Item Snapshot (10.020B)
    DECLARE @example_error INT;
    SELECT @example_error = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE ITEMNMBR = '10.020B'
      AND NOT (
          -- Same-day PO offsets negative drift: expect positive or zero ATP balance after PO
          (Row_Type = 'PURCHASE_ORDER' AND ATP_Running_Balance >= 0)
          OR (Row_Type <> 'PURCHASE_ORDER')
      );

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_example_item_snapshot',
        CASE WHEN @example_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @example_error = 0 THEN 'Example item 10.020B shows expected behavior' ELSE 'Example item does not match expected snapshot' END,
        @example_error
    );

    -- Test 16: Deficit Calculations in StockOut Analysis
    DECLARE @deficit_error INT;
    SELECT @deficit_error = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE (ATP_Running_Balance < 0 AND Deficit_ATP <> ABS(ATP_Running_Balance))
       OR (ATP_Running_Balance >= 0 AND Deficit_ATP <> 0)
       OR (Forecast_Running_Balance < 0 AND Deficit_Forecast <> ABS(Forecast_Running_Balance))
       OR (Forecast_Running_Balance >= 0 AND Deficit_Forecast <> 0);

    INSERT INTO #TestResults (test_name, pass, message, rows_affected)
    VALUES (
        'test_deficit_calculations',
        CASE WHEN @deficit_error = 0 THEN 1 ELSE 0 END,
        CASE WHEN @deficit_error = 0 THEN 'Deficit calculations correct' ELSE 'Found ' + CAST(@deficit_error AS NVARCHAR(10)) + ' deficit errors' END,
        @deficit_error
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
