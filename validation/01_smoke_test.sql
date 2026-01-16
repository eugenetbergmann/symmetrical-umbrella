/*
===============================================================================
Smoke Test: Rolyat Stock-Out Intelligence Pipeline v2.0
Description: Basic existence and data return checks for all core views
Version: 2.0.0
Last Modified: 2026-01-16

Purpose:
  - Verify all core pipeline views exist and are accessible
  - Confirm basic data flow without errors
  - Quick sanity check before deeper validation

Execution:
  - Run in SQL Server Management Studio or equivalent
  - Should complete without errors if pipeline is properly deployed
===============================================================================
*/

-- Test 1: Cleaned Base Demand
PRINT 'Testing dbo.Rolyat_Cleaned_Base_Demand_1...';
IF OBJECT_ID('dbo.Rolyat_Cleaned_Base_Demand_1', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_Cleaned_Base_Demand_1 view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count1 INT = (SELECT COUNT(*) FROM dbo.Rolyat_Cleaned_Base_Demand_1);
    PRINT 'PASS: dbo.Rolyat_Cleaned_Base_Demand_1 exists with ' + CAST(@count1 AS NVARCHAR(10)) + ' rows';
END

-- Test 2: WC Inventory
PRINT 'Testing dbo.Rolyat_WC_Inventory...';
IF OBJECT_ID('dbo.Rolyat_WC_Inventory', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_WC_Inventory view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count2 INT = (SELECT COUNT(*) FROM dbo.Rolyat_WC_Inventory);
    PRINT 'PASS: dbo.Rolyat_WC_Inventory exists with ' + CAST(@count2 AS NVARCHAR(10)) + ' rows';
END

-- Test 3: WFQ
PRINT 'Testing dbo.Rolyat_WFQ_5...';
IF OBJECT_ID('dbo.Rolyat_WFQ_5', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_WFQ_5 view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count3 INT = (SELECT COUNT(*) FROM dbo.Rolyat_WFQ_5);
    PRINT 'PASS: dbo.Rolyat_WFQ_5 exists with ' + CAST(@count3 AS NVARCHAR(10)) + ' rows';
END

-- Test 4: WC Allocation Effective
PRINT 'Testing dbo.Rolyat_WC_Allocation_Effective_2...';
IF OBJECT_ID('dbo.Rolyat_WC_Allocation_Effective_2', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_WC_Allocation_Effective_2 view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count4 INT = (SELECT COUNT(*) FROM dbo.Rolyat_WC_Allocation_Effective_2);
    PRINT 'PASS: dbo.Rolyat_WC_Allocation_Effective_2 exists with ' + CAST(@count4 AS NVARCHAR(10)) + ' rows';
END

-- Test 5: Unit Price
PRINT 'Testing dbo.Rolyat_Unit_Price_4...';
IF OBJECT_ID('dbo.Rolyat_Unit_Price_4', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_Unit_Price_4 view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count5 INT = (SELECT COUNT(*) FROM dbo.Rolyat_Unit_Price_4);
    PRINT 'PASS: dbo.Rolyat_Unit_Price_4 exists with ' + CAST(@count5 AS NVARCHAR(10)) + ' rows';
END

-- Test 6: Final Ledger
PRINT 'Testing dbo.Rolyat_Final_Ledger_3...';
IF OBJECT_ID('dbo.Rolyat_Final_Ledger_3', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_Final_Ledger_3 view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count6 INT = (SELECT COUNT(*) FROM dbo.Rolyat_Final_Ledger_3);
    PRINT 'PASS: dbo.Rolyat_Final_Ledger_3 exists with ' + CAST(@count6 AS NVARCHAR(10)) + ' rows';
END

-- Test 7: Stock Out Analysis
PRINT 'Testing dbo.Rolyat_StockOut_Analysis_v2...';
IF OBJECT_ID('dbo.Rolyat_StockOut_Analysis_v2', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_StockOut_Analysis_v2 view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count7 INT = (SELECT COUNT(*) FROM dbo.Rolyat_StockOut_Analysis_v2);
    PRINT 'PASS: dbo.Rolyat_StockOut_Analysis_v2 exists with ' + CAST(@count7 AS NVARCHAR(10)) + ' rows';
END

-- Test 8: Rebalancing Layer
PRINT 'Testing dbo.Rolyat_Rebalancing_Layer...';
IF OBJECT_ID('dbo.Rolyat_Rebalancing_Layer', 'V') IS NULL
BEGIN
    RAISERROR('FAIL: dbo.Rolyat_Rebalancing_Layer view does not exist', 16, 1);
END
ELSE
BEGIN
    DECLARE @count8 INT = (SELECT COUNT(*) FROM dbo.Rolyat_Rebalancing_Layer);
    PRINT 'PASS: dbo.Rolyat_Rebalancing_Layer exists with ' + CAST(@count8 AS NVARCHAR(10)) + ' rows';
END

PRINT 'Smoke test completed. Check for any FAIL messages above.';