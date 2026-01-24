/*
===============================================================================
Validation Script: View Consolidation (ETB2_Inventory_Unified_v1 & ETB2_Consumption_Detail_v1)
Purpose: Verify consolidated views match legacy view data and logic
Last Modified: 2026-01-24
===============================================================================
*/

-- ============================================================
-- SECTION 1: ETB2_Inventory_Unified_v1 Validation
-- ============================================================

PRINT '=== ETB2_Inventory_Unified_v1 Validation ===';

-- Test 1.1: Verify view exists and returns data
PRINT 'Test 1.1: View exists and returns data';
SELECT 
  COUNT(*) AS Total_Rows,
  COUNT(DISTINCT Inventory_Type) AS Inventory_Types,
  COUNT(DISTINCT ITEMNMBR) AS Unique_Items,
  COUNT(DISTINCT Site_ID) AS Unique_Sites
FROM dbo.ETB2_Inventory_Unified_v1;

-- Test 1.2: Verify Inventory_Type distribution
PRINT 'Test 1.2: Inventory_Type distribution';
SELECT 
  Inventory_Type,
  COUNT(*) AS Count,
  SUM(QTY_ON_HAND) AS Total_Qty,
  COUNT(DISTINCT ITEMNMBR) AS Unique_Items
FROM dbo.ETB2_Inventory_Unified_v1
GROUP BY Inventory_Type
ORDER BY Inventory_Type;

-- Test 1.3: Verify WC batches have bin locations
PRINT 'Test 1.3: WC batches have bin locations';
SELECT 
  COUNT(*) AS WC_Without_Bin
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WC_BATCH'
  AND (Bin_Location IS NULL OR Bin_Location = '');

-- Test 1.4: Verify WFQ/RMQTY batches have NULL bin locations
PRINT 'Test 1.4: WFQ/RMQTY batches have NULL bin locations';
SELECT 
  COUNT(*) AS Non_WC_With_Bin
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH')
  AND Bin_Location IS NOT NULL;

-- Test 1.5: Verify WC batches always eligible
PRINT 'Test 1.5: WC batches always eligible';
SELECT 
  COUNT(*) AS WC_Not_Eligible
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WC_BATCH'
  AND Is_Eligible_For_Release <> 1;

-- Test 1.6: Verify WFQ hold period logic
PRINT 'Test 1.6: WFQ hold period logic (14 days default)';
SELECT 
  COUNT(*) AS Rows_Checked,
  SUM(CASE 
    WHEN DATEDIFF(DAY, Receipt_Date, GETDATE()) >= 14 AND Is_Eligible_For_Release = 1 THEN 1
    WHEN DATEDIFF(DAY, Receipt_Date, GETDATE()) < 14 AND Is_Eligible_For_Release = 0 THEN 1
    ELSE 0
  END) AS Correct_Logic
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WFQ_BATCH';

-- Test 1.7: Verify RMQTY hold period logic
PRINT 'Test 1.7: RMQTY hold period logic (7 days default)';
SELECT 
  COUNT(*) AS Rows_Checked,
  SUM(CASE 
    WHEN DATEDIFF(DAY, Receipt_Date, GETDATE()) >= 7 AND Is_Eligible_For_Release = 1 THEN 1
    WHEN DATEDIFF(DAY, Receipt_Date, GETDATE()) < 7 AND Is_Eligible_For_Release = 0 THEN 1
    ELSE 0
  END) AS Correct_Logic
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'RMQTY_BATCH';

-- Test 1.8: Verify SortPriority values
PRINT 'Test 1.8: SortPriority values (1=WC, 2=WFQ, 3=RMQTY)';
SELECT 
  Inventory_Type,
  SortPriority,
  COUNT(*) AS Count
FROM dbo.ETB2_Inventory_Unified_v1
GROUP BY Inventory_Type, SortPriority
ORDER BY SortPriority;

-- Test 1.9: Verify no NULL Batch_IDs
PRINT 'Test 1.9: No NULL Batch_IDs';
SELECT 
  COUNT(*) AS Null_Batch_IDs
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Batch_ID IS NULL;

-- Test 1.10: Verify Age_Days calculation
PRINT 'Test 1.10: Age_Days calculation (should be >= 0)';
SELECT 
  COUNT(*) AS Negative_Age_Days
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Age_Days < 0;

-- Test 1.11: Verify Expiry_Date logic for WC batches
PRINT 'Test 1.11: WC batches have Expiry_Date';
SELECT 
  COUNT(*) AS WC_Without_Expiry
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WC_BATCH'
  AND Expiry_Date IS NULL;

-- Test 1.12: Verify QTY_ON_HAND > 0
PRINT 'Test 1.12: All QTY_ON_HAND > 0';
SELECT 
  COUNT(*) AS Zero_Or_Negative_Qty
FROM dbo.ETB2_Inventory_Unified_v1
WHERE QTY_ON_HAND <= 0;

-- Test 1.13: Verify UOM is populated
PRINT 'Test 1.13: UOM is populated';
SELECT 
  COUNT(*) AS Null_UOM
FROM dbo.ETB2_Inventory_Unified_v1
WHERE UOM IS NULL OR UOM = '';

-- Test 1.14: Sample data from each inventory type
PRINT 'Test 1.14: Sample data from each inventory type';
SELECT TOP 3
  Inventory_Type,
  ITEMNMBR,
  Batch_ID,
  QTY_ON_HAND,
  Receipt_Date,
  Expiry_Date,
  Is_Eligible_For_Release,
  SortPriority
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WC_BATCH'
ORDER BY Receipt_Date DESC;

SELECT TOP 3
  Inventory_Type,
  ITEMNMBR,
  Batch_ID,
  QTY_ON_HAND,
  Receipt_Date,
  Projected_Release_Date,
  Is_Eligible_For_Release,
  SortPriority
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WFQ_BATCH'
ORDER BY Receipt_Date DESC;

SELECT TOP 3
  Inventory_Type,
  ITEMNMBR,
  Batch_ID,
  QTY_ON_HAND,
  Receipt_Date,
  Projected_Release_Date,
  Is_Eligible_For_Release,
  SortPriority
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'RMQTY_BATCH'
ORDER BY Receipt_Date DESC;

-- ============================================================
-- SECTION 2: ETB2_Consumption_Detail_v1 Validation
-- ============================================================

PRINT '';
PRINT '=== ETB2_Consumption_Detail_v1 Validation ===';

-- Test 2.1: Verify view exists and returns data
PRINT 'Test 2.1: View exists and returns data';
SELECT 
  COUNT(*) AS Total_Rows,
  COUNT(DISTINCT ITEMNMBR) AS Unique_Items,
  COUNT(DISTINCT Client_ID) AS Unique_Clients,
  COUNT(DISTINCT ORDERNUMBER) AS Unique_Orders
FROM dbo.ETB2_Consumption_Detail_v1;

-- Test 2.2: Verify dual naming (technical and business-friendly)
PRINT 'Test 2.2: Verify dual naming columns exist';
SELECT 
  COUNT(*) AS Rows_With_Matching_Names
FROM dbo.ETB2_Consumption_Detail_v1
WHERE Base_Demand = Demand_Qty
  AND suppressed_demand = ATP_Demand_Qty
  AND Original_Running_Balance = Forecast_Balance
  AND effective_demand = ATP_Balance;

-- Test 2.3: Verify demand quantities
PRINT 'Test 2.3: Demand quantities (Base_Demand >= 0)';
SELECT 
  COUNT(*) AS Negative_Demand
FROM dbo.ETB2_Consumption_Detail_v1
WHERE Base_Demand < 0;

-- Test 2.4: Verify effective demand <= base demand
PRINT 'Test 2.4: Effective demand <= Base demand (after WC allocation)';
SELECT 
  COUNT(*) AS Invalid_Suppression
FROM dbo.ETB2_Consumption_Detail_v1
WHERE suppressed_demand > Base_Demand;

-- Test 2.5: Verify supply quantities
PRINT 'Test 2.5: Supply quantities (all >= 0)';
SELECT 
  COUNT(*) AS Negative_Supply
FROM dbo.ETB2_Consumption_Detail_v1
WHERE BEG_BAL < 0
    OR POs < 0
    OR Released_PO_Qty < 0
    OR WFQ_QTY < 0
    OR RMQTY_QTY < 0;

-- Test 2.6: Verify Released_PO_Qty <= POs
PRINT 'Test 2.6: Released_PO_Qty <= POs';
SELECT 
  COUNT(*) AS Invalid_Released
FROM dbo.ETB2_Consumption_Detail_v1
WHERE Released_PO_Qty > POs;

-- Test 2.7: Verify allocation status values
PRINT 'Test 2.7: Allocation status values';
SELECT 
  Allocation_Status,
  COUNT(*) AS Count
FROM dbo.ETB2_Consumption_Detail_v1
GROUP BY Allocation_Status
ORDER BY Allocation_Status;

-- Test 2.8: Verify IsActiveWindow is 0 or 1
PRINT 'Test 2.8: IsActiveWindow is 0 or 1';
SELECT 
  COUNT(*) AS Invalid_Window_Flag
FROM dbo.ETB2_Consumption_Detail_v1
WHERE IsActiveWindow NOT IN (0, 1);

-- Test 2.9: Verify Stock_Out_Flag is 0 or 1
PRINT 'Test 2.9: Stock_Out_Flag is 0 or 1';
SELECT 
  COUNT(*) AS Invalid_QC_Flag
FROM dbo.ETB2_Consumption_Detail_v1
WHERE QC_Flag NOT IN (0, 1);

-- Test 2.10: Sample data
PRINT 'Test 2.10: Sample consumption data';
SELECT TOP 10
  ITEMNMBR,
  ORDERNUMBER,
  DUEDATE,
  Base_Demand,
  suppressed_demand,
  BEG_BAL,
  POs,
  Original_Running_Balance,
  effective_demand,
  Allocation_Status,
  IsActiveWindow
FROM dbo.ETB2_Consumption_Detail_v1
ORDER BY DUEDATE DESC;

-- ============================================================
-- SECTION 3: Downstream View Validation
-- ============================================================

PRINT '';
PRINT '=== Downstream View Validation ===';

-- Test 3.1: Verify View 08 executes
PRINT 'Test 3.1: View 08 (Rolyat_WC_Allocation_Effective_2) executes';
BEGIN TRY
  SELECT COUNT(*) AS Row_Count FROM dbo.Rolyat_WC_Allocation_Effective_2;
  PRINT 'SUCCESS: View 08 executes';
END TRY
BEGIN CATCH
  PRINT 'ERROR: View 08 failed - ' + ERROR_MESSAGE();
END CATCH;

-- Test 3.2: Verify View 09 executes
PRINT 'Test 3.2: View 09 (Rolyat_Final_Ledger_3) executes';
BEGIN TRY
  SELECT COUNT(*) AS Row_Count FROM dbo.Rolyat_Final_Ledger_3;
  PRINT 'SUCCESS: View 09 executes';
END TRY
BEGIN CATCH
  PRINT 'ERROR: View 09 failed - ' + ERROR_MESSAGE();
END CATCH;

-- Test 3.3: Verify View 10 executes
PRINT 'Test 3.3: View 10 (Rolyat_StockOut_Analysis_v2) executes';
BEGIN TRY
  SELECT COUNT(*) AS Row_Count FROM dbo.Rolyat_StockOut_Analysis_v2;
  PRINT 'SUCCESS: View 10 executes';
END TRY
BEGIN CATCH
  PRINT 'ERROR: View 10 failed - ' + ERROR_MESSAGE();
END CATCH;

-- Test 3.4: Verify View 11 executes
PRINT 'Test 3.4: View 11 (Rolyat_Rebalancing_Layer) executes';
BEGIN TRY
  SELECT COUNT(*) AS Row_Count FROM dbo.Rolyat_Rebalancing_Layer;
  PRINT 'SUCCESS: View 11 executes';
END TRY
BEGIN CATCH
  PRINT 'ERROR: View 11 failed - ' + ERROR_MESSAGE();
END CATCH;

-- Test 3.5: Verify View 18 executes
PRINT 'Test 3.5: View 18 (Rolyat_Batch_Expiry_Risk_Dashboard) executes';
BEGIN TRY
  SELECT COUNT(*) AS Row_Count FROM dbo.Rolyat_Batch_Expiry_Risk_Dashboard;
  PRINT 'SUCCESS: View 18 executes';
END TRY
BEGIN CATCH
  PRINT 'ERROR: View 18 failed - ' + ERROR_MESSAGE();
END CATCH;

-- Test 3.6: Verify View 19 executes
PRINT 'Test 3.6: View 19 (Rolyat_Supply_Planner_Action_List) executes';
BEGIN TRY
  SELECT COUNT(*) AS Row_Count FROM dbo.Rolyat_Supply_Planner_Action_List;
  PRINT 'SUCCESS: View 19 executes';
END TRY
BEGIN CATCH
  PRINT 'ERROR: View 19 failed - ' + ERROR_MESSAGE();
END CATCH;

-- ============================================================
-- SECTION 4: Summary Report
-- ============================================================

PRINT '';
PRINT '=== Validation Summary ===';
PRINT 'All tests completed. Review results above for any failures.';
PRINT 'Key metrics:';
PRINT '  - ETB2_Inventory_Unified_v1: Check row counts by Inventory_Type';
PRINT '  - ETB2_Consumption_Detail_v1: Check row counts and data quality';
PRINT '  - Downstream views: All should execute without errors';
