/*
===============================================================================
View: dbo.ETB2_Presentation_Dashboard_v1
Description: Unified dashboard consolidating stock-out, expiry, and action views
Version: 2.0.0
Last Modified: 2026-01-24
Dependencies:
   - dbo.Rolyat_StockOut_Analysis_v2 (stock-out analysis)
   - dbo.Rolyat_Final_Ledger_3 (final ledger)
   - dbo.ETB2_Inventory_Unified_v1 (unified inventory)
   - dbo.Rolyat_PO_Detail (PO details)
   - dbo.ETB2_PAB_EventLedger_v1 (event ledger)

Purpose:
   - Consolidates 3 separate dashboard views into single intelligent view
   - Provides smart filtering for different audiences (Executive, Planner, Expiry)
   - Eliminates duplicate risk scoring and action recommendation logic
   - Supports multiple presentation layers from single data source

Business Rules:
   - Risk categorization: CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK, HEALTHY
   - Action recommendations prioritize urgency
   - Focuses on items with active risk (not HEALTHY status)
   - Includes demand projection for planning context
   - Batch expiry risks tracked with clear timeline
   - Supply planner actions prioritized by business impact

REPLACES:
   - dbo.Rolyat_StockOut_Risk_Dashboard (View 17)
   - dbo.Rolyat_Batch_Expiry_Risk_Dashboard (View 18)
   - dbo.Rolyat_Supply_Planner_Action_List (View 19)

USAGE:
   - Executive view: Filter WHERE Dashboard_Type = 'STOCKOUT_RISK'
   - Planner view: Filter WHERE Dashboard_Type = 'PLANNER_ACTIONS'
   - Expiry view: Filter WHERE Dashboard_Type = 'BATCH_EXPIRY'

FILTERING EXAMPLES:
   -- Executive dashboard (stock-out risk only)
   SELECT * FROM dbo.ETB2_Presentation_Dashboard_v1
   WHERE Dashboard_Type = 'STOCKOUT_RISK'
   ORDER BY Action_Priority, Item_Number;

   -- Planner action list (prioritized by urgency)
   SELECT * FROM dbo.ETB2_Presentation_Dashboard_v1
   WHERE Dashboard_Type = 'PLANNER_ACTIONS'
   ORDER BY Action_Priority, Item_Number;

   -- Expiry risk dashboard (batch-level visibility)
   SELECT * FROM dbo.ETB2_Presentation_Dashboard_v1
   WHERE Dashboard_Type = 'BATCH_EXPIRY'
   ORDER BY Days_Until_Expiry, Item_Number;
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Presentation_Dashboard_v1
AS

-- ============================================================
-- STOCKOUT RISK DASHBOARD (Executive View)
-- ============================================================
SELECT
  'STOCKOUT_RISK' AS Dashboard_Type,
  1 AS Display_Priority,
  soa.CleanItem AS Item_Number,
  soa.Client_ID,
  NULL AS Site_ID,
  soa.effective_demand AS Current_ATP_Balance,
  CASE 
    WHEN soa.effective_demand <= 0 THEN 'CRITICAL_STOCKOUT'
    WHEN soa.effective_demand < 50 THEN 'HIGH_RISK'
    WHEN soa.effective_demand < 100 THEN 'MEDIUM_RISK'
    ELSE 'HEALTHY'
  END AS Risk_Level,
  CASE 
    WHEN soa.effective_demand <= 0 THEN 'URGENT_PURCHASE'
    WHEN soa.effective_demand <= 7 THEN 'EXPEDITE_OPEN_POS'
    WHEN soa.effective_demand <= 14 THEN 'TRANSFER_FROM_OTHER_SITES'
    ELSE 'MONITOR'
  END AS Recommended_Action,
  soa.Alternate_Stock AS Available_Alternate_Stock_Qty,
  soa.Original_Running_Balance AS Forecast_Balance_Before_Allocation,
  soa.WFQ_QTY,
  soa.RMQTY_QTY,
  NULL AS Batch_ID,
  NULL AS Batch_Type,
  NULL AS Days_Until_Expiry,
  NULL AS Expiry_Risk_Tier,
  NULL AS Batch_Qty,
  NULL AS Business_Impact,
  CASE 
    WHEN soa.effective_demand <= 0 THEN 1
    WHEN soa.effective_demand < 50 THEN 2
    WHEN soa.effective_demand < 100 THEN 3
    ELSE 4
  END AS Action_Priority

FROM dbo.Rolyat_StockOut_Analysis_v2 soa

WHERE
  CASE 
    WHEN soa.effective_demand <= 0 THEN 'CRITICAL_STOCKOUT'
    WHEN soa.effective_demand < 50 THEN 'HIGH_RISK'
    WHEN soa.effective_demand < 100 THEN 'MEDIUM_RISK'
    ELSE 'HEALTHY'
  END <> 'HEALTHY'

UNION ALL

-- ============================================================
-- BATCH EXPIRY RISK DASHBOARD (Inventory View)
-- ============================================================
SELECT
  'BATCH_EXPIRY' AS Dashboard_Type,
  2 AS Display_Priority,
  inv.ITEMNMBR AS Item_Number,
  inv.Client_ID,
  inv.Site_ID,
  inv.QTY_ON_HAND AS Current_ATP_Balance,
  CASE 
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) < 0 THEN 'EXPIRED'
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 30 THEN 'CRITICAL'
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 60 THEN 'HIGH'
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 90 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS Risk_Level,
  CASE 
    WHEN inv.Inventory_Type = 'WC_BATCH' THEN 'USE_FIRST'
    WHEN inv.Inventory_Type = 'WFQ_BATCH' AND DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) > 14 THEN 'RELEASE_AFTER_HOLD'
    WHEN inv.Inventory_Type = 'WFQ_BATCH' THEN 'HOLD_IN_WFQ'
    WHEN inv.Inventory_Type = 'RMQTY_BATCH' AND DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) > 7 THEN 'RELEASE_AFTER_HOLD'
    WHEN inv.Inventory_Type = 'RMQTY_BATCH' THEN 'HOLD_IN_RMQTY'
    ELSE 'UNKNOWN'
  END AS Recommended_Action,
  NULL AS Available_Alternate_Stock_Qty,
  NULL AS Forecast_Balance_Before_Allocation,
  NULL AS WFQ_QTY,
  NULL AS RMQTY_QTY,
  inv.Batch_ID,
  inv.Inventory_Type AS Batch_Type,
  DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) AS Days_Until_Expiry,
  CASE 
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) < 0 THEN 'EXPIRED'
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 30 THEN 'CRITICAL'
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 60 THEN 'HIGH'
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 90 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS Expiry_Risk_Tier,
  inv.QTY_ON_HAND AS Batch_Qty,
  CASE 
    WHEN inv.QTY_ON_HAND * 100 > 10000 THEN 'HIGH'
    WHEN inv.QTY_ON_HAND * 100 > 5000 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS Business_Impact,
  CASE 
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) < 0 THEN 1
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 30 THEN 2
    WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 60 THEN 3
    ELSE 4
  END AS Action_Priority

FROM dbo.ETB2_Inventory_Unified_v1 inv

WHERE inv.Expiry_Date IS NOT NULL
  AND DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) <= 90

UNION ALL

-- ============================================================
-- SUPPLY PLANNER ACTION LIST (Operational View)
-- Priority 1: Critical stock-outs
-- ============================================================
SELECT
  'PLANNER_ACTIONS' AS Dashboard_Type,
  3 AS Display_Priority,
  soa.CleanItem AS Item_Number,
  soa.Client_ID,
  NULL AS Site_ID,
  soa.effective_demand AS Current_ATP_Balance,
  'CRITICAL_STOCKOUT' AS Risk_Level,
  'URGENT_PURCHASE' AS Recommended_Action,
  NULL AS Available_Alternate_Stock_Qty,
  NULL AS Forecast_Balance_Before_Allocation,
  NULL AS WFQ_QTY,
  NULL AS RMQTY_QTY,
  NULL AS Batch_ID,
  NULL AS Batch_Type,
  NULL AS Days_Until_Expiry,
  NULL AS Expiry_Risk_Tier,
  NULL AS Batch_Qty,
  'HIGH' AS Business_Impact,
  1 AS Action_Priority

FROM dbo.Rolyat_StockOut_Analysis_v2 soa

WHERE soa.effective_demand <= 0

UNION ALL

-- Priority 2: High risk items (< 7 days cover)
SELECT
  'PLANNER_ACTIONS' AS Dashboard_Type,
  3 AS Display_Priority,
  soa.CleanItem AS Item_Number,
  soa.Client_ID,
  NULL AS Site_ID,
  soa.effective_demand AS Current_ATP_Balance,
  'HIGH_RISK_STOCK' AS Risk_Level,
  'EXPEDITE_OPEN_POS' AS Recommended_Action,
  NULL AS Available_Alternate_Stock_Qty,
  NULL AS Forecast_Balance_Before_Allocation,
  NULL AS WFQ_QTY,
  NULL AS RMQTY_QTY,
  NULL AS Batch_ID,
  NULL AS Batch_Type,
  NULL AS Days_Until_Expiry,
  NULL AS Expiry_Risk_Tier,
  NULL AS Batch_Qty,
  'HIGH' AS Business_Impact,
  2 AS Action_Priority

FROM dbo.Rolyat_StockOut_Analysis_v2 soa

WHERE soa.effective_demand > 0 
  AND soa.effective_demand < 50

UNION ALL

-- Priority 3: Critical expiry batches
SELECT
  'PLANNER_ACTIONS' AS Dashboard_Type,
  3 AS Display_Priority,
  inv.ITEMNMBR AS Item_Number,
  inv.Client_ID,
  inv.Site_ID,
  inv.QTY_ON_HAND AS Current_ATP_Balance,
  'CRITICAL_EXPIRY' AS Risk_Level,
  'USE_FIRST' AS Recommended_Action,
  NULL AS Available_Alternate_Stock_Qty,
  NULL AS Forecast_Balance_Before_Allocation,
  NULL AS WFQ_QTY,
  NULL AS RMQTY_QTY,
  inv.Batch_ID,
  inv.Inventory_Type AS Batch_Type,
  DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) AS Days_Until_Expiry,
  'CRITICAL' AS Expiry_Risk_Tier,
  inv.QTY_ON_HAND AS Batch_Qty,
  CASE 
    WHEN inv.QTY_ON_HAND * 100 > 10000 THEN 'HIGH'
    WHEN inv.QTY_ON_HAND * 100 > 5000 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS Business_Impact,
  3 AS Action_Priority

FROM dbo.ETB2_Inventory_Unified_v1 inv

WHERE inv.Expiry_Date IS NOT NULL
  AND DATEDIFF(DAY, CAST(GETDATE() AS DATE), inv.Expiry_Date) BETWEEN 0 AND 30

UNION ALL

-- Priority 4: Past due POs
SELECT
  'PLANNER_ACTIONS' AS Dashboard_Type,
  3 AS Display_Priority,
  po.ITEMNMBR AS Item_Number,
  NULL AS Client_ID,
  po.Site_ID,
  po.Open_PO_Qty AS Current_ATP_Balance,
  'PAST_DUE_PO' AS Risk_Level,
  'FOLLOW_UP' AS Recommended_Action,
  NULL AS Available_Alternate_Stock_Qty,
  NULL AS Forecast_Balance_Before_Allocation,
  NULL AS WFQ_QTY,
  NULL AS RMQTY_QTY,
  NULL AS Batch_ID,
  NULL AS Batch_Type,
  NULL AS Days_Until_Expiry,
  NULL AS Expiry_Risk_Tier,
  po.Open_PO_Qty AS Batch_Qty,
  'MEDIUM' AS Business_Impact,
  4 AS Action_Priority

FROM dbo.Rolyat_PO_Detail po

WHERE po.PO_Due_Date < CAST(GETDATE() AS DATE)
  AND po.Open_PO_Qty > 0;
