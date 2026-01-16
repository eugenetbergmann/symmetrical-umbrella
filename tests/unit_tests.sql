/*
================================================================================
Unit Tests for Rolyat Pipeline
Description: Comprehensive test suite for all pipeline views
Version: 2.0.0
Last Modified: 2026-01-16

Test Categories:
  1. Running Balance Identity Tests
  2. Event Ordering Tests
  3. Active Window Tests
  4. WC Allocation Tests
  5. Supply Event Tests
  6. Stock-Out Intelligence Tests
  7. Data Integrity Tests
  8. Edge Case Tests
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

CREATE OR ALTER PROCEDURE tests.sp_run_unit_tests
AS
BEGIN
    SET NOCOUNT ON;

    -- ============================================================
    -- Create temp table for test results
    -- ============================================================
    CREATE TABLE #TestResults (
        test_id INT IDENTITY(1,1),
        test_category NVARCHAR(50),
        test_name NVARCHAR(100),
        pass BIT,
        message NVARCHAR(MAX),
        rows_affected INT,
        execution_time_ms INT
    );

    DECLARE @start_time DATETIME2;
    DECLARE @mismatches INT;

    -- ============================================================
    -- CATEGORY 1: Running Balance Identity Tests
    -- ============================================================

    -- Test 1.1: Forecast Running Balance Identity
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE Forecast_Running_Balance <> ISNULL(
        LAG(Forecast_Running_Balance) OVER (
            PARTITION BY ITEMNMBR 
            ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ), 0)
        + Forecast_Supply_Event
        - Base_Demand;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Running Balance',
        'test_forecast_running_balance_identity',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All Forecast balances match identity formula' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' Forecast balance mismatches' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 1.2: ATP Running Balance Identity
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE ATP_Running_Balance <> ISNULL(
        LAG(ATP_Running_Balance) OVER (
            PARTITION BY ITEMNMBR, Client_ID 
            ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ), 0)
        + ATP_Supply_Event
        - Effective_Demand;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Running Balance',
        'test_atp_running_balance_identity',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All ATP balances match identity formula' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' ATP balance mismatches' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 1.3: Adjusted Running Balance matches ATP
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE Adjusted_Running_Balance <> ATP_Running_Balance;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Running Balance',
        'test_adjusted_equals_atp_balance',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'Adjusted_Running_Balance equals ATP_Running_Balance' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' mismatches between Adjusted and ATP' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- CATEGORY 2: Event Ordering Tests
    -- ============================================================

    -- Test 2.1: SortPriority Presence (no NULLs)
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*) 
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 
    WHERE SortPriority IS NULL;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Event Ordering',
        'test_sortpriority_not_null',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'No NULL SortPriority values' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' NULL SortPriority values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 2.2: SortPriority Valid Range (1-5)
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*) 
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 
    WHERE SortPriority NOT BETWEEN 1 AND 5;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Event Ordering',
        'test_sortpriority_valid_range',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All SortPriority values in valid range (1-5)' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' out-of-range SortPriority values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 2.3: Beginning Balance has SortPriority = 1
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*) 
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 
    WHERE BEG_BAL > 0 AND SortPriority <> 1;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Event Ordering',
        'test_beg_bal_sortpriority',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All Beginning Balance rows have SortPriority = 1' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' BEG_BAL rows with wrong SortPriority' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- CATEGORY 3: Active Window Tests
    -- ============================================================

    -- Test 3.1: Active Window Flagging Correctness
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Cleaned_Base_Demand_1
    WHERE (DUEDATE BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE()) AND IsActiveWindow <> 1)
       OR (DUEDATE NOT BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE()) AND IsActiveWindow <> 0);

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Active Window',
        'test_active_window_flagging',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'Active window flags correctly set for ±21 day window' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' incorrect IsActiveWindow flags' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 3.2: IsActiveWindow is binary (0 or 1)
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*) 
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 
    WHERE IsActiveWindow NOT IN (0, 1);

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Active Window',
        'test_active_window_binary',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All IsActiveWindow values are binary (0 or 1)' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' non-binary IsActiveWindow values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- CATEGORY 4: WC Allocation Tests
    -- ============================================================

    -- Test 4.1: ATP Suppression Within Window Only
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE IsActiveWindow = 1
      AND effective_demand > Base_Demand;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'WC Allocation',
        'test_effective_demand_not_exceeds_base',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'Effective demand never exceeds Base demand' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' rows where effective > base demand' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 4.2: No Suppression Outside Window
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE IsActiveWindow = 0
      AND effective_demand <> Base_Demand;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'WC Allocation',
        'test_no_suppression_outside_window',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'No demand suppression outside active window' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' suppressed rows outside window' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 4.3: No Double Allocation (allocated <= batch effective qty)
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM (
        SELECT WC_Batch_ID
        FROM dbo.Rolyat_WC_Allocation_Effective_2
        WHERE WC_Batch_ID IS NOT NULL
        GROUP BY WC_Batch_ID
        HAVING SUM(COALESCE(allocated, 0)) > MAX(COALESCE(WC_Effective_Qty, 0))
    ) AS over_allocated;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'WC Allocation',
        'test_no_double_allocation',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'No WC batches over-allocated' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' over-allocated WC batches' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 4.4: Allocation Status Consistency
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE (IsActiveWindow = 0 AND Allocation_Status <> 'OUTSIDE_WINDOW')
       OR (IsActiveWindow = 1 AND Total_WC_Available > 0 AND Allocation_Status <> 'WC_ALLOCATED')
       OR (IsActiveWindow = 1 AND COALESCE(Total_WC_Available, 0) = 0 AND Allocation_Status <> 'NO_WC_AVAILABLE');

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'WC Allocation',
        'test_allocation_status_consistency',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'Allocation status consistent with window and availability' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' inconsistent allocation statuses' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 4.5: Degradation Factor Valid Range
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_WC_Allocation_Effective_2
    WHERE Degradation_Factor IS NOT NULL
      AND (Degradation_Factor < 0 OR Degradation_Factor > 1);

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'WC Allocation',
        'test_degradation_factor_range',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All degradation factors in valid range (0-1)' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' out-of-range degradation factors' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- CATEGORY 5: Supply Event Tests
    -- ============================================================

    -- Test 5.1: Forecast Supply Event Non-Negative
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE Forecast_Supply_Event < 0;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Supply Events',
        'test_forecast_supply_non_negative',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All Forecast supply events are non-negative' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' negative Forecast supply events' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 5.2: ATP Supply Event Non-Negative
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE ATP_Supply_Event < 0;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Supply Events',
        'test_atp_supply_non_negative',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All ATP supply events are non-negative' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' negative ATP supply events' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 5.3: ATP Supply <= Forecast Supply (ATP is conservative)
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE ATP_Supply_Event > Forecast_Supply_Event;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Supply Events',
        'test_atp_supply_conservative',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'ATP supply never exceeds Forecast supply (conservative)' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' rows where ATP > Forecast supply' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- CATEGORY 6: Stock-Out Intelligence Tests
    -- ============================================================

    -- Test 6.1: Stock-Out Flag Consistency
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE (ATP_Running_Balance < 0 AND Stock_Out_Flag <> 1)
       OR (ATP_Running_Balance >= 0 AND Stock_Out_Flag <> 0);

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Stock-Out Intelligence',
        'test_stockout_flag_consistency',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'Stock_Out_Flag consistent with ATP balance' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' inconsistent Stock_Out_Flag values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 6.2: Action Tag Validity
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE Action_Tag NOT IN ('NORMAL', 'ATP_CONSTRAINED', 'URGENT_PURCHASE', 'URGENT_TRANSFER', 
                             'URGENT_EXPEDITE', 'REVIEW_ALTERNATE_STOCK', 'STOCK_OUT');

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Stock-Out Intelligence',
        'test_action_tag_validity',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All Action_Tag values are valid' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' invalid Action_Tag values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 6.3: Deficit Calculation Correctness
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE (ATP_Running_Balance < 0 AND Deficit_ATP <> ABS(ATP_Running_Balance))
       OR (ATP_Running_Balance >= 0 AND Deficit_ATP <> 0)
       OR (Forecast_Running_Balance < 0 AND Deficit_Forecast <> ABS(Forecast_Running_Balance))
       OR (Forecast_Running_Balance >= 0 AND Deficit_Forecast <> 0);

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Stock-Out Intelligence',
        'test_deficit_calculations',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'Deficit calculations are correct' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' incorrect deficit calculations' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 6.4: QC Review Condition
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE (ATP_Running_Balance < 0 AND Alternate_Stock <= 0 AND Updated_QC_Flag <> 'REVIEW_NO_WC_AVAILABLE')
       OR (NOT (ATP_Running_Balance < 0 AND Alternate_Stock <= 0) AND Updated_QC_Flag = 'REVIEW_NO_WC_AVAILABLE');

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Stock-Out Intelligence',
        'test_qc_review_condition',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'QC review conditions are correct' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' incorrect QC review flags' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- CATEGORY 7: Data Integrity Tests
    -- ============================================================

    -- Test 7.1: No NULL ITEMNMBR
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Cleaned_Base_Demand_1
    WHERE ITEMNMBR IS NULL OR TRIM(ITEMNMBR) = '';

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Data Integrity',
        'test_no_null_itemnmbr',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'No NULL or empty ITEMNMBR values' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' NULL/empty ITEMNMBR values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 7.2: No NULL ORDERNUMBER
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Cleaned_Base_Demand_1
    WHERE ORDERNUMBER IS NULL OR TRIM(ORDERNUMBER) = '';

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Data Integrity',
        'test_no_null_ordernumber',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'No NULL or empty ORDERNUMBER values' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' NULL/empty ORDERNUMBER values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 7.3: Valid Date_Expiry
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Cleaned_Base_Demand_1
    WHERE Date_Expiry IS NULL;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Data Integrity',
        'test_valid_date_expiry',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All Date_Expiry values are valid' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' NULL Date_Expiry values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 7.4: Base_Demand Non-Negative
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Cleaned_Base_Demand_1
    WHERE Base_Demand < 0;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Data Integrity',
        'test_base_demand_non_negative',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All Base_Demand values are non-negative' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' negative Base_Demand values' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 7.5: Excluded Item Prefixes
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Cleaned_Base_Demand_1
    WHERE ITEMNMBR LIKE '60.%' OR ITEMNMBR LIKE '70.%';

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Data Integrity',
        'test_excluded_item_prefixes',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'No excluded item prefixes (60.x, 70.x) present' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' excluded item prefixes' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- CATEGORY 8: Edge Case Tests
    -- ============================================================

    -- Test 8.1: WFQ Eligibility Flag Consistency
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_WFQ_5
    WHERE (Projected_Release_Date <= GETDATE() AND Is_Eligible_For_Release <> 1)
       OR (Projected_Release_Date > GETDATE() AND Is_Eligible_For_Release <> 0);

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Edge Cases',
        'test_wfq_eligibility_consistency',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'WFQ eligibility flags consistent with release dates' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' inconsistent WFQ eligibility flags' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 8.2: WC Inventory Positive Quantity
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_WC_Inventory
    WHERE Available_Qty <= 0;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Edge Cases',
        'test_wc_inventory_positive_qty',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'All WC inventory has positive quantity' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' non-positive WC inventory quantities' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- Test 8.3: WC Allocation Applied Flag Consistency
    SET @start_time = GETDATE();
    SELECT @mismatches = COUNT(*)
    FROM dbo.Rolyat_Final_Ledger_3
    WHERE (IsActiveWindow = 1 AND effective_demand < Base_Demand AND WC_Allocation_Applied_Flag <> 1)
       OR (NOT (IsActiveWindow = 1 AND effective_demand < Base_Demand) AND WC_Allocation_Applied_Flag = 1);

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Edge Cases',
        'test_wc_allocation_applied_flag',
        CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
        CASE WHEN @mismatches = 0 THEN 'WC_Allocation_Applied_Flag consistent with suppression' 
             ELSE 'Found ' + CAST(@mismatches AS NVARCHAR(10)) + ' inconsistent WC allocation flags' END,
        @mismatches,
        DATEDIFF(MILLISECOND, @start_time, GETDATE())
    );

    -- ============================================================
    -- Coverage Metric
    -- ============================================================
    DECLARE @total_tests INT;
    DECLARE @passed_tests INT;
    
    SELECT @total_tests = COUNT(*), @passed_tests = SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END)
    FROM #TestResults;

    INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
    VALUES (
        'Coverage',
        'test_coverage_metric',
        CASE WHEN @passed_tests = @total_tests THEN 1 ELSE 0 END,
        CAST(@passed_tests AS NVARCHAR(10)) + '/' + CAST(@total_tests AS NVARCHAR(10)) + ' tests passed (' + 
            CAST(CAST(@passed_tests AS FLOAT) / NULLIF(@total_tests, 0) * 100 AS NVARCHAR(10)) + '%)',
        @passed_tests,
        0
    );

    -- ============================================================
    -- Return Results
    -- ============================================================
    SELECT 
        test_id,
        test_category,
        test_name,
        CASE WHEN pass = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
        message,
        rows_affected,
        execution_time_ms
    FROM #TestResults 
    ORDER BY test_category, test_name;

    -- Summary by Category
    SELECT
        test_category,
        COUNT(*) AS total_tests,
        SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS passed_tests,
        SUM(CASE WHEN pass = 0 THEN 1 ELSE 0 END) AS failed_tests,
        CAST(SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS pass_percentage
    FROM #TestResults
    WHERE test_category <> 'Coverage'
    GROUP BY test_category
    ORDER BY test_category;

    -- Overall Summary
    SELECT
        COUNT(*) AS total_tests,
        SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS passed_tests,
        SUM(CASE WHEN pass = 0 THEN 1 ELSE 0 END) AS failed_tests,
        CAST(SUM(CASE WHEN pass = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS pass_percentage,
        SUM(execution_time_ms) AS total_execution_time_ms
    FROM #TestResults
    WHERE test_category <> 'Coverage';

    DROP TABLE #TestResults;
END
GO

-- Add extended property for documentation
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Comprehensive unit test suite for Rolyat pipeline views. Tests running balances, event ordering, active window, WC allocation, supply events, stock-out intelligence, data integrity, and edge cases.',
    @level0type = N'SCHEMA', @level0name = 'tests',
    @level1type = N'PROCEDURE', @level1name = 'sp_run_unit_tests'
GO
