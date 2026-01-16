/*
================================================================================
Violation Detection Queries for Rolyat Pipeline
Description: Standalone assertion queries for existing data validation
Version: 2.0.0
Last Modified: 2026-01-16

Usage:
  - Execute each query independently
  - PASS: Query returns 0 rows (no violations)
  - FAIL: Query returns ≥1 rows (violations detected)
  - Examine returned rows to identify specific failures
================================================================================
*/

USE [MED];
GO

SET NOCOUNT ON;
GO

-- ============================================================
-- TEST 1: WC Demand Suppression Tests
-- ============================================================

-- Test 1.1: Demands within window with WC inventory but not suppressed
-- Expected: 0 rows (all demands with WC should be suppressed within window)
SELECT 
    'FAILURE: Test 1.1 - Unsuppressed demand within window' AS Failure_Type,
    ORDERNUMBER, 
    ITEMNMBR, 
    Date_Expiry, 
    Base_Demand, 
    effective_demand, 
    WC_Batch_ID,
    IsActiveWindow
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE IsActiveWindow = 1
    AND WC_Batch_ID IS NOT NULL
    AND effective_demand = Base_Demand
    AND Base_Demand > 0;
GO

-- Test 1.2: Demands outside window incorrectly suppressed
-- Expected: 0 rows (no suppression should occur outside window)
SELECT 
    'FAILURE: Test 1.2 - Suppressed demand outside window' AS Failure_Type,
    ORDERNUMBER, 
    ITEMNMBR, 
    Date_Expiry, 
    Base_Demand, 
    effective_demand,
    IsActiveWindow
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE IsActiveWindow = 0
    AND effective_demand < Base_Demand;
GO

-- Test 1.3: Effective demand exceeds base demand
-- Expected: 0 rows (effective should never exceed base)
SELECT 
    'FAILURE: Test 1.3 - Effective demand exceeds base' AS Failure_Type,
    ORDERNUMBER, 
    ITEMNMBR, 
    Date_Expiry, 
    Base_Demand, 
    effective_demand
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE effective_demand > Base_Demand;
GO

-- ============================================================
-- TEST 2: Event Ordering Tests
-- ============================================================

-- Test 2.1: NULL SortPriority values
-- Expected: 0 rows (all rows should have SortPriority)
SELECT 
    'FAILURE: Test 2.1 - NULL SortPriority' AS Failure_Type,
    ORDERNUMBER, 
    ITEMNMBR, 
    Date_Expiry
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE SortPriority IS NULL;
GO

-- Test 2.2: Invalid SortPriority range
-- Expected: 0 rows (SortPriority should be 1-5)
SELECT 
    'FAILURE: Test 2.2 - Invalid SortPriority range' AS Failure_Type,
    ORDERNUMBER, 
    ITEMNMBR, 
    SortPriority
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE SortPriority NOT BETWEEN 1 AND 5;
GO

-- ============================================================
-- TEST 3: Inventory Degradation Tests
-- ============================================================

-- Test 3.1: Incorrect degradation factors
-- Expected: 0 rows (degradation should match age tiers)
SELECT 
    'FAILURE: Test 3.1 - Wrong degradation factor' AS Failure_Type,
    ORDERNUMBER, 
    ITEMNMBR, 
    WC_Age_Days, 
    WC_Degradation_Factor,
    CASE
        WHEN WC_Age_Days <= 30 THEN 1.00
        WHEN WC_Age_Days <= 60 THEN 0.75
        WHEN WC_Age_Days <= 90 THEN 0.50
        ELSE 0.00
    END AS Expected_Factor
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE WC_Degradation_Factor IS NOT NULL
    AND WC_Degradation_Factor <> CASE
        WHEN WC_Age_Days <= 30 THEN 1.00
        WHEN WC_Age_Days <= 60 THEN 0.75
        WHEN WC_Age_Days <= 90 THEN 0.50
        ELSE 0.00
    END;
GO

-- Test 3.2: Degradation factor out of valid range
-- Expected: 0 rows (factor should be 0-1)
SELECT 
    'FAILURE: Test 3.2 - Degradation factor out of range' AS Failure_Type,
    ORDERNUMBER, 
    ITEMNMBR, 
    WC_Degradation_Factor
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE WC_Degradation_Factor IS NOT NULL
    AND (WC_Degradation_Factor < 0 OR WC_Degradation_Factor > 1);
GO

-- ============================================================
-- TEST 4: Double Allocation Tests
-- ============================================================

-- Test 4.1: Double allocation - allocated exceeds batch effective qty
-- Expected: 0 rows (no batch should be over-allocated)
SELECT 
    'FAILURE: Test 4.1 - Double allocation' AS Failure_Type,
    WC_Batch_ID, 
    SUM(COALESCE(allocated, 0)) AS Total_Allocated, 
    MAX(COALESCE(WC_Effective_Qty, 0)) AS Batch_Effective_Qty
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE WC_Batch_ID IS NOT NULL
GROUP BY WC_Batch_ID
HAVING SUM(COALESCE(allocated, 0)) > MAX(COALESCE(WC_Effective_Qty, 0));
GO

-- ============================================================
-- TEST 5: Running Balance Tests
-- ============================================================

-- Test 5.1: Running balance anomalies (unexpected increases without supply)
-- Expected: 0 rows (balance should only increase with supply events)
SELECT 
    'FAILURE: Test 5.1 - Balance anomaly' AS Failure_Type,
    ITEMNMBR, 
    Date_Expiry, 
    ORDERNUMBER,
    Adjusted_Running_Balance, 
    Prev_Balance,
    Adjusted_Running_Balance - Prev_Balance AS Unexpected_Increase
FROM (
    SELECT 
        ITEMNMBR, 
        Date_Expiry, 
        ORDERNUMBER, 
        Adjusted_Running_Balance,
        LAG(Adjusted_Running_Balance) OVER (
            PARTITION BY ITEMNMBR, Client_ID 
            ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ) AS Prev_Balance,
        ATP_Supply_Event,
        effective_demand
    FROM dbo.Rolyat_Final_Ledger_3
) AS balance_check
WHERE Adjusted_Running_Balance > Prev_Balance
    AND Prev_Balance IS NOT NULL
    AND ATP_Supply_Event = 0;
GO

-- Test 5.2: Stock_Out_Flag inconsistency
-- Expected: 0 rows (flag should match balance sign)
SELECT 
    'FAILURE: Test 5.2 - Stock_Out_Flag inconsistency' AS Failure_Type,
    ITEMNMBR, 
    ORDERNUMBER,
    ATP_Running_Balance, 
    Stock_Out_Flag
FROM dbo.Rolyat_Final_Ledger_3
WHERE (ATP_Running_Balance < 0 AND Stock_Out_Flag <> 1)
   OR (ATP_Running_Balance >= 0 AND Stock_Out_Flag <> 0);
GO

-- ============================================================
-- TEST 6: Stock-Out Intelligence Tests
-- ============================================================

-- Test 6.1: Invalid stock-out signals (deficit with available alternate stock)
-- Expected: Review rows for potential false positives
SELECT 
    'REVIEW: Test 6.1 - Deficit with alternate stock' AS Review_Type,
    fl.ITEMNMBR, 
    fl.CleanItem,
    fl.Adjusted_Running_Balance, 
    wfq.QTY_ON_HAND AS Alternate_Stock
FROM dbo.Rolyat_Final_Ledger_3 AS fl
LEFT JOIN dbo.Rolyat_WFQ_5 AS wfq 
    ON fl.CleanItem = wfq.Item_Number
WHERE fl.Row_Type = 'DEMAND_EVENT'
    AND fl.Adjusted_Running_Balance < 0
    AND wfq.QTY_ON_HAND > 0;
GO

-- Test 6.2: Invalid Action_Tag values
-- Expected: 0 rows (all tags should be from valid set)
SELECT 
    'FAILURE: Test 6.2 - Invalid Action_Tag' AS Failure_Type,
    ITEMNMBR, 
    ORDERNUMBER,
    Action_Tag
FROM dbo.Rolyat_StockOut_Analysis_v2
WHERE Action_Tag NOT IN (
    'NORMAL', 
    'ATP_CONSTRAINED', 
    'URGENT_PURCHASE', 
    'URGENT_TRANSFER', 
    'URGENT_EXPEDITE', 
    'REVIEW_ALTERNATE_STOCK', 
    'STOCK_OUT'
);
GO

-- Test 6.3: Deficit calculation errors
-- Expected: 0 rows (deficit should equal absolute value of negative balance)
SELECT 
    'FAILURE: Test 6.3 - Deficit calculation error' AS Failure_Type,
    ITEMNMBR, 
    ORDERNUMBER,
    ATP_Running_Balance,
    Deficit_ATP,
    ABS(ATP_Running_Balance) AS Expected_Deficit
FROM dbo.Rolyat_StockOut_Analysis_v2
WHERE (ATP_Running_Balance < 0 AND Deficit_ATP <> ABS(ATP_Running_Balance))
   OR (ATP_Running_Balance >= 0 AND Deficit_ATP <> 0);
GO

-- ============================================================
-- TEST 7: Data Integrity Tests
-- ============================================================

-- Test 7.1: NULL or empty ITEMNMBR
-- Expected: 0 rows
SELECT 
    'FAILURE: Test 7.1 - NULL/empty ITEMNMBR' AS Failure_Type,
    ORDERNUMBER
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE ITEMNMBR IS NULL OR TRIM(ITEMNMBR) = '';
GO

-- Test 7.2: Excluded item prefixes present
-- Expected: 0 rows (60.x and 70.x should be filtered)
SELECT 
    'FAILURE: Test 7.2 - Excluded item prefix' AS Failure_Type,
    ITEMNMBR, 
    ORDERNUMBER
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE ITEMNMBR LIKE '60.%' OR ITEMNMBR LIKE '70.%';
GO

-- Test 7.3: Negative Base_Demand
-- Expected: 0 rows (demand should be non-negative)
SELECT 
    'FAILURE: Test 7.3 - Negative Base_Demand' AS Failure_Type,
    ITEMNMBR, 
    ORDERNUMBER,
    Base_Demand
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE Base_Demand < 0;
GO

-- ============================================================
-- TEST 8: WFQ/RMQTY Tests
-- ============================================================

-- Test 8.1: WFQ eligibility flag inconsistency
-- Expected: 0 rows
SELECT 
    'FAILURE: Test 8.1 - WFQ eligibility inconsistency' AS Failure_Type,
    ITEMNMBR, 
    Batch_ID,
    Projected_Release_Date,
    Is_Eligible_For_Release
FROM dbo.Rolyat_WFQ_5
WHERE (Projected_Release_Date <= GETDATE() AND Is_Eligible_For_Release <> 1)
   OR (Projected_Release_Date > GETDATE() AND Is_Eligible_For_Release <> 0);
GO

-- Test 8.2: Invalid Inventory_Type
-- Expected: 0 rows
SELECT 
    'FAILURE: Test 8.2 - Invalid Inventory_Type' AS Failure_Type,
    ITEMNMBR, 
    Batch_ID,
    Inventory_Type
FROM dbo.Rolyat_WFQ_5
WHERE Inventory_Type NOT IN ('WFQ', 'RMQTY');
GO

-- Test 8.3: Negative QTY_ON_HAND
-- Expected: 0 rows
SELECT 
    'FAILURE: Test 8.3 - Negative QTY_ON_HAND' AS Failure_Type,
    ITEMNMBR, 
    Batch_ID,
    QTY_ON_HAND
FROM dbo.Rolyat_WFQ_5
WHERE QTY_ON_HAND < 0;
GO

-- ============================================================
-- SUMMARY: Run all tests and count failures
-- ============================================================
PRINT '============================================================';
PRINT 'Assertion Test Summary';
PRINT '============================================================';
PRINT 'Execute each query above individually.';
PRINT 'PASS: Query returns 0 rows';
PRINT 'FAIL: Query returns ≥1 rows';
PRINT '';
PRINT 'For detailed test execution with metrics, use:';
PRINT 'EXEC tests.sp_run_unit_tests;';
PRINT '============================================================';
GO
