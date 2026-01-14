-- Assertion Queries for Unit Tests

USE [MED]
GO

-- 1.1 WC Demand Deprecation - Valid Reduction
SELECT 'Test 1.1' AS Test, effective_demand, wc_allocation_status
FROM Rolyat_WC_PAB_effective_demand
WHERE ORDERNUMBER = 'TEST_ORDER1'
-- Expected: effective_demand = 50, wc_allocation_status = 'WC_Suppressed'

-- 1.2 WC Demand Deprecation - No Reduction Outside Window
SELECT 'Test 1.2' AS Test, effective_demand, wc_allocation_status
FROM Rolyat_WC_PAB_effective_demand
WHERE ORDERNUMBER = 'TEST_ORDER2'
-- Expected: effective_demand = 100, wc_allocation_status = 'Outside_Active_Window'

-- 3.1 Degradation 15 Days
SELECT 'Test 3.1' AS Test, WC_Degradation_Factor
FROM Rolyat_WC_PAB_with_prioritized_inventory
WHERE ORDERNUMBER = 'TEST_DEG15'
-- Expected: 1.00

-- 3.2 Degradation 45 Days
SELECT 'Test 3.2' AS Test, WC_Degradation_Factor
FROM Rolyat_WC_PAB_with_prioritized_inventory
WHERE ORDERNUMBER = 'TEST_DEG45'
-- Expected: 0.75

-- 3.3 Degradation 95 Days
SELECT 'Test 3.3' AS Test, WC_Degradation_Factor
FROM Rolyat_WC_PAB_with_prioritized_inventory
WHERE ORDERNUMBER = 'TEST_DEG95'
-- Expected: 0.00

-- 4.1 No Double Allocation
SELECT 'Test 4.1' AS Test, SUM(allocated) AS Total_Allocated
FROM Rolyat_WC_PAB_with_allocation
WHERE ITEMNMBR = 'TEST_DOUBLE'
-- Expected: <= 100

-- 5.1 Running Balance Correctness
SELECT 'Test 5.1' AS Test, ITEMNMBR, Date_Expiry, Adjusted_Running_Balance
FROM Rolyat_Final_Ledger
WHERE ITEMNMBR = 'TEST_BAL'
ORDER BY Date_Expiry
-- Expected: Balance decreases monotonically

-- 7.1 Stock-Out Intelligence
SELECT 'Test 7.1' AS Test, Coverage_Classification, Action_Priority
FROM Rolyat_StockOut_Analysis_v2
WHERE ITEMNMBR = 'TEST_STOCKOUT'  -- Assuming test data added
-- Expected: Based on setup

GO