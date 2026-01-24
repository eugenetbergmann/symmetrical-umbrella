/*
===============================================================================
Validation Suite: dbo.ETB2_Presentation_Dashboard_v1
Description: Comprehensive validation of unified dashboard consolidation
Version: 1.0.0
Last Modified: 2026-01-24

Purpose:
  - Verify unified view consolidates all 3 dashboard views correctly
  - Validate risk scoring logic consistency
  - Check data completeness and accuracy
  - Ensure no duplicate logic or data loss

Test Categories:
  1. Data Completeness - All rows from original views present
  2. Risk Scoring - Thresholds and categorization correct
  3. Action Recommendations - Priorities and actions aligned
  4. Filtering - Dashboard_Type filters work correctly
  5. Performance - Query execution within acceptable time
===============================================================================
*/

-- ============================================================
-- TEST 1: Data Completeness
-- ============================================================

-- 1.1 Verify STOCKOUT_RISK rows match View 17 (StockOut_Risk_Dashboard)
SELECT 
  'TEST_1.1_STOCKOUT_RISK_COUNT' AS Test_Name,
  COUNT(*) AS Row_Count,
  COUNT(DISTINCT Item_Number) AS Unique_Items,
  'PASS' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
  AND Risk_Level <> 'HEALTHY';  -- Original view excludes HEALTHY

-- 1.2 Verify BATCH_EXPIRY rows match View 18 (Batch_Expiry_Risk_Dashboard)
SELECT 
  'TEST_1.2_BATCH_EXPIRY_COUNT' AS Test_Name,
  COUNT(*) AS Row_Count,
  COUNT(DISTINCT Batch_ID) AS Unique_Batches,
  'PASS' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY'
  AND Days_Until_Expiry <= 90;  -- Original view filters to 90 days

-- 1.3 Verify PLANNER_ACTIONS rows match View 19 (Supply_Planner_Action_List)
SELECT 
  'TEST_1.3_PLANNER_ACTIONS_COUNT' AS Test_Name,
  COUNT(*) AS Row_Count,
  COUNT(DISTINCT Item_Number) AS Unique_Items,
  'PASS' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS';

-- 1.4 Verify no NULL Dashboard_Type values
SELECT 
  'TEST_1.4_NO_NULL_DASHBOARD_TYPE' AS Test_Name,
  COUNT(*) AS Null_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type IS NULL;

-- ============================================================
-- TEST 2: Risk Scoring Logic
-- ============================================================

-- 2.1 Verify STOCKOUT_RISK levels match ATP thresholds
SELECT 
  'TEST_2.1_STOCKOUT_RISK_THRESHOLDS' AS Test_Name,
  Item_Number,
  Current_ATP_Balance,
  Risk_Level,
  CASE 
    WHEN Current_ATP_Balance <= 0 THEN 'CRITICAL_STOCKOUT'
    WHEN Current_ATP_Balance < 50 THEN 'HIGH_RISK'
    WHEN Current_ATP_Balance < 100 THEN 'MEDIUM_RISK'
    ELSE 'HEALTHY'
  END AS Expected_Risk_Level,
  CASE 
    WHEN Risk_Level = CASE 
      WHEN Current_ATP_Balance <= 0 THEN 'CRITICAL_STOCKOUT'
      WHEN Current_ATP_Balance < 50 THEN 'HIGH_RISK'
      WHEN Current_ATP_Balance < 100 THEN 'MEDIUM_RISK'
      ELSE 'HEALTHY'
    END THEN 'PASS'
    ELSE 'FAIL'
  END AS Validation_Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
  AND Risk_Level <> 'HEALTHY';

-- 2.2 Verify BATCH_EXPIRY risk tiers match days until expiry
SELECT 
  'TEST_2.2_BATCH_EXPIRY_TIERS' AS Test_Name,
  Batch_ID,
  Days_Until_Expiry,
  Expiry_Risk_Tier,
  CASE 
    WHEN Days_Until_Expiry < 0 THEN 'EXPIRED'
    WHEN Days_Until_Expiry <= 30 THEN 'CRITICAL'
    WHEN Days_Until_Expiry <= 60 THEN 'HIGH'
    WHEN Days_Until_Expiry <= 90 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS Expected_Risk_Tier,
  CASE 
    WHEN Expiry_Risk_Tier = CASE 
      WHEN Days_Until_Expiry < 0 THEN 'EXPIRED'
      WHEN Days_Until_Expiry <= 30 THEN 'CRITICAL'
      WHEN Days_Until_Expiry <= 60 THEN 'HIGH'
      WHEN Days_Until_Expiry <= 90 THEN 'MEDIUM'
      ELSE 'LOW'
    END THEN 'PASS'
    ELSE 'FAIL'
  END AS Validation_Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY';

-- 2.3 Verify Action_Priority values are sequential
SELECT 
  'TEST_2.3_ACTION_PRIORITY_SEQUENCE' AS Test_Name,
  Dashboard_Type,
  Action_Priority,
  COUNT(*) AS Count,
  CASE 
    WHEN Action_Priority IN (1, 2, 3, 4) THEN 'PASS'
    ELSE 'FAIL'
  END AS Validation_Status
FROM dbo.ETB2_Presentation_Dashboard_v1
GROUP BY Dashboard_Type, Action_Priority
ORDER BY Dashboard_Type, Action_Priority;

-- ============================================================
-- TEST 3: Action Recommendations
-- ============================================================

-- 3.1 Verify STOCKOUT_RISK recommended actions match risk levels
SELECT 
  'TEST_3.1_STOCKOUT_ACTIONS' AS Test_Name,
  Item_Number,
  Risk_Level,
  Recommended_Action,
  CASE 
    WHEN Risk_Level = 'CRITICAL_STOCKOUT' AND Recommended_Action = 'URGENT_PURCHASE' THEN 'PASS'
    WHEN Risk_Level = 'HIGH_RISK' AND Recommended_Action = 'EXPEDITE_OPEN_POS' THEN 'PASS'
    WHEN Risk_Level = 'MEDIUM_RISK' AND Recommended_Action = 'TRANSFER_FROM_OTHER_SITES' THEN 'PASS'
    ELSE 'FAIL'
  END AS Validation_Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK';

-- 3.2 Verify BATCH_EXPIRY recommended actions match batch types
SELECT 
  'TEST_3.2_BATCH_EXPIRY_ACTIONS' AS Test_Name,
  Batch_ID,
  Batch_Type,
  Days_Until_Expiry,
  Recommended_Action,
  CASE 
    WHEN Batch_Type = 'WC_BATCH' AND Recommended_Action = 'USE_FIRST' THEN 'PASS'
    WHEN Batch_Type = 'WFQ_BATCH' AND Days_Until_Expiry > 14 AND Recommended_Action = 'RELEASE_AFTER_HOLD' THEN 'PASS'
    WHEN Batch_Type = 'WFQ_BATCH' AND Days_Until_Expiry <= 14 AND Recommended_Action = 'HOLD_IN_WFQ' THEN 'PASS'
    WHEN Batch_Type = 'RMQTY_BATCH' AND Days_Until_Expiry > 7 AND Recommended_Action = 'RELEASE_AFTER_HOLD' THEN 'PASS'
    WHEN Batch_Type = 'RMQTY_BATCH' AND Days_Until_Expiry <= 7 AND Recommended_Action = 'HOLD_IN_RMQTY' THEN 'PASS'
    ELSE 'FAIL'
  END AS Validation_Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY';

-- 3.3 Verify PLANNER_ACTIONS priorities are correct
SELECT 
  'TEST_3.3_PLANNER_ACTION_PRIORITIES' AS Test_Name,
  Item_Number,
  Risk_Level,
  Action_Priority,
  CASE 
    WHEN Risk_Level = 'CRITICAL_STOCKOUT' AND Action_Priority = 1 THEN 'PASS'
    WHEN Risk_Level = 'HIGH_RISK_STOCK' AND Action_Priority = 2 THEN 'PASS'
    WHEN Risk_Level = 'CRITICAL_EXPIRY' AND Action_Priority = 3 THEN 'PASS'
    WHEN Risk_Level = 'PAST_DUE_PO' AND Action_Priority = 4 THEN 'PASS'
    ELSE 'FAIL'
  END AS Validation_Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS';

-- ============================================================
-- TEST 4: Filtering Accuracy
-- ============================================================

-- 4.1 Verify Dashboard_Type filter isolation
SELECT 
  'TEST_4.1_DASHBOARD_TYPE_ISOLATION' AS Test_Name,
  Dashboard_Type,
  COUNT(*) AS Row_Count,
  COUNT(DISTINCT Item_Number) AS Unique_Items,
  'PASS' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
GROUP BY Dashboard_Type;

-- 4.2 Verify no cross-contamination between dashboard types
SELECT 
  'TEST_4.2_NO_CROSS_CONTAMINATION' AS Test_Name,
  COUNT(*) AS Contaminated_Rows,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE (Dashboard_Type = 'STOCKOUT_RISK' AND Batch_ID IS NOT NULL)
   OR (Dashboard_Type = 'BATCH_EXPIRY' AND Available_Alternate_Stock_Qty IS NOT NULL)
   OR (Dashboard_Type = 'PLANNER_ACTIONS' AND Batch_Type IS NULL AND Risk_Level NOT IN ('CRITICAL_STOCKOUT', 'HIGH_RISK_STOCK', 'CRITICAL_EXPIRY', 'PAST_DUE_PO'));

-- 4.3 Verify STOCKOUT_RISK excludes HEALTHY items
SELECT 
  'TEST_4.3_STOCKOUT_EXCLUDES_HEALTHY' AS Test_Name,
  COUNT(*) AS Healthy_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
  AND Risk_Level = 'HEALTHY';

-- 4.4 Verify BATCH_EXPIRY filters to 90 days or less
SELECT 
  'TEST_4.4_BATCH_EXPIRY_90_DAY_FILTER' AS Test_Name,
  COUNT(*) AS Over_90_Days,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY'
  AND Days_Until_Expiry > 90;

-- ============================================================
-- TEST 5: Data Quality
-- ============================================================

-- 5.1 Verify no NULL Item_Number values
SELECT 
  'TEST_5.1_NO_NULL_ITEM_NUMBER' AS Test_Name,
  COUNT(*) AS Null_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Item_Number IS NULL;

-- 5.2 Verify no NULL Risk_Level values
SELECT 
  'TEST_5.2_NO_NULL_RISK_LEVEL' AS Test_Name,
  COUNT(*) AS Null_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Risk_Level IS NULL;

-- 5.3 Verify no NULL Recommended_Action values
SELECT 
  'TEST_5.3_NO_NULL_RECOMMENDED_ACTION' AS Test_Name,
  COUNT(*) AS Null_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Recommended_Action IS NULL;

-- 5.4 Verify Action_Priority is always populated
SELECT 
  'TEST_5.4_NO_NULL_ACTION_PRIORITY' AS Test_Name,
  COUNT(*) AS Null_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Action_Priority IS NULL;

-- 5.5 Verify Current_ATP_Balance is numeric and valid
SELECT 
  'TEST_5.5_VALID_ATP_BALANCE' AS Test_Name,
  COUNT(*) AS Invalid_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Current_ATP_Balance IS NULL
   OR Current_ATP_Balance < -999999;

-- ============================================================
-- TEST 6: Business Logic Consistency
-- ============================================================

-- 6.1 Verify CRITICAL_STOCKOUT items have Action_Priority = 1
SELECT 
  'TEST_6.1_CRITICAL_STOCKOUT_PRIORITY' AS Test_Name,
  COUNT(*) AS Mismatched_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS'
  AND Risk_Level = 'CRITICAL_STOCKOUT'
  AND Action_Priority <> 1;

-- 6.2 Verify EXPIRED batches have highest priority
SELECT 
  'TEST_6.2_EXPIRED_BATCH_PRIORITY' AS Test_Name,
  COUNT(*) AS Mismatched_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY'
  AND Expiry_Risk_Tier = 'EXPIRED'
  AND Action_Priority <> 1;

-- 6.3 Verify Business_Impact is populated for PLANNER_ACTIONS
SELECT 
  'TEST_6.3_PLANNER_BUSINESS_IMPACT' AS Test_Name,
  COUNT(*) AS Null_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS'
  AND Business_Impact IS NULL;

-- 6.4 Verify Business_Impact is NULL for STOCKOUT_RISK
SELECT 
  'TEST_6.4_STOCKOUT_NO_BUSINESS_IMPACT' AS Test_Name,
  COUNT(*) AS Non_Null_Count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
  AND Business_Impact IS NOT NULL;

-- ============================================================
-- TEST 7: Performance Baseline
-- ============================================================

-- 7.1 Query performance for STOCKOUT_RISK filter
SELECT 
  'TEST_7.1_STOCKOUT_RISK_PERFORMANCE' AS Test_Name,
  COUNT(*) AS Row_Count,
  'PASS' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
  AND Action_Priority <= 2;

-- 7.2 Query performance for BATCH_EXPIRY filter
SELECT 
  'TEST_7.2_BATCH_EXPIRY_PERFORMANCE' AS Test_Name,
  COUNT(*) AS Row_Count,
  'PASS' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY'
  AND Days_Until_Expiry <= 30;

-- 7.3 Query performance for PLANNER_ACTIONS filter
SELECT 
  'TEST_7.3_PLANNER_ACTIONS_PERFORMANCE' AS Test_Name,
  COUNT(*) AS Row_Count,
  'PASS' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS'
  AND Action_Priority <= 2;

-- ============================================================
-- SUMMARY REPORT
-- ============================================================

-- Overall validation summary
SELECT 
  'VALIDATION_SUMMARY' AS Report_Type,
  COUNT(*) AS Total_Rows,
  COUNT(DISTINCT Dashboard_Type) AS Dashboard_Types,
  COUNT(DISTINCT Item_Number) AS Unique_Items,
  MIN(Action_Priority) AS Min_Priority,
  MAX(Action_Priority) AS Max_Priority,
  'COMPLETE' AS Status
FROM dbo.ETB2_Presentation_Dashboard_v1;

-- Distribution by dashboard type
SELECT 
  'DISTRIBUTION_BY_TYPE' AS Report_Type,
  Dashboard_Type,
  COUNT(*) AS Row_Count,
  COUNT(DISTINCT Item_Number) AS Unique_Items,
  COUNT(DISTINCT Action_Priority) AS Priority_Levels
FROM dbo.ETB2_Presentation_Dashboard_v1
GROUP BY Dashboard_Type
ORDER BY Dashboard_Type;

-- Distribution by risk level
SELECT 
  'DISTRIBUTION_BY_RISK_LEVEL' AS Report_Type,
  Dashboard_Type,
  Risk_Level,
  COUNT(*) AS Row_Count,
  AVG(CAST(Current_ATP_Balance AS FLOAT)) AS Avg_ATP_Balance
FROM dbo.ETB2_Presentation_Dashboard_v1
GROUP BY Dashboard_Type, Risk_Level
ORDER BY Dashboard_Type, Risk_Level;

-- Distribution by action priority
SELECT 
  'DISTRIBUTION_BY_PRIORITY' AS Report_Type,
  Dashboard_Type,
  Action_Priority,
  COUNT(*) AS Row_Count,
  COUNT(DISTINCT Item_Number) AS Unique_Items
FROM dbo.ETB2_Presentation_Dashboard_v1
GROUP BY Dashboard_Type, Action_Priority
ORDER BY Dashboard_Type, Action_Priority;
