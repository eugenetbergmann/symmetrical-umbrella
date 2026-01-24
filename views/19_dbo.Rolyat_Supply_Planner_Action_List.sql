/*
================================================================================
View: dbo.Rolyat_Supply_Planner_Action_List
Description: Prioritized action list for supply planners (7 columns max)
Version: 1.1.0
Last Modified: 2026-01-24
Dependencies:
  - dbo.Rolyat_StockOut_Analysis_v2
  - dbo.ETB2_Inventory_Unified_v1 (replaces Rolyat_WC_Inventory)
  - dbo.Rolyat_PO_Detail
  - dbo.ETB2_PAB_EventLedger_v1

Purpose:
  - Provides supply planners with actionable, prioritized task list
  - Tells the story: "Here's what to do this week, in priority order"
  - Optimized for single-screen viewing with 7 columns max
  - Combines stock-out risks, expiry risks, and PO delays
  - No CTEs - direct query for performance

Business Rules:
  - Priority 1: Critical stock-outs (ATP <= 0) - URGENT_PURCHASE
  - Priority 2: High risk items (ATP < 50, < 7 days cover) - EXPEDITE_OPEN_POS
  - Priority 3: Critical expiry batches (< 30 days to expiry) - USE_FIRST
  - Priority 4: Past due POs (Expected_Date < TODAY) - FOLLOW_UP
  - Business impact calculated based on financial exposure
================================================================================
*/

-- Priority 1: Critical stock-outs
SELECT 
    1 AS Action_Priority,
    ITEMNMBR,
    'CRITICAL_STOCKOUT' AS Action_Category,
    'URGENT_PURCHASE: ' + CAST(ABS(Current_ATP_Balance) AS VARCHAR) + ' units needed' AS Action_Detail,
    'TODAY' AS Recommended_Deadline,
    'HIGH' AS Business_Impact,
    Client_ID

FROM dbo.Rolyat_StockOut_Analysis_v2
WHERE Current_ATP_Balance <= 0

UNION ALL

-- Priority 2: High risk items (< 7 days cover)
SELECT 
    2 AS Action_Priority,
    ITEMNMBR,
    'HIGH_RISK_STOCK' AS Action_Category,
    'EXPEDITE_OPEN_POS: ' + CAST(Current_ATP_Balance AS VARCHAR) + ' units left' AS Action_Detail,
    'WITHIN_3_DAYS' AS Recommended_Deadline,
    'HIGH' AS Business_Impact,
    Client_ID

FROM dbo.Rolyat_StockOut_Analysis_v2
WHERE Current_ATP_Balance > 0 
  AND Current_ATP_Balance < 50
  AND Days_of_Cover_ATP <= 7

UNION ALL

-- Priority 3: Critical expiry batches
SELECT 
    3 AS Action_Priority,
    ExpiringBatches.ITEMNMBR,
    'CRITICAL_EXPIRY' AS Action_Category,
    'USE_FIRST: Batch ' + ExpiringBatches.Batch_ID + ' (' + CAST(ExpiringBatches.Batch_Qty AS VARCHAR) + ' units)' AS Action_Detail,
    'WITHIN_7_DAYS' AS Recommended_Deadline,
    CASE 
        WHEN ExpiringBatches.Batch_Qty * ExpiringBatches.Unit_Cost > 10000 THEN 'HIGH'
        WHEN ExpiringBatches.Batch_Qty * ExpiringBatches.Unit_Cost > 5000 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Business_Impact,
    ExpiringBatches.Client_ID

FROM (
    SELECT
        ITEMNMBR,
        Batch_ID,
        SUM(QTY_ON_HAND) AS Batch_Qty,
        Client_ID,
        0 AS Unit_Cost  -- Unit cost not available in unified view
    FROM dbo.ETB2_Inventory_Unified_v1
    WHERE Inventory_Type = 'WC_BATCH'
      AND DATEDIFF(day, GETDATE(), Expiry_Date) <= 30
      AND DATEDIFF(day, GETDATE(), Expiry_Date) >= 0
    GROUP BY ITEMNMBR, Batch_ID, Client_ID
) ExpiringBatches
WHERE ExpiringBatches.Batch_Qty > 0

UNION ALL

-- Priority 4: Past due POs
SELECT 
    4 AS Action_Priority,
    PO_Detail.ITEMNMBR,
    'PAST_DUE_PO' AS Action_Category,
    'FOLLOW_UP: PO ' + PO_Detail.PO_Number + ' (' + CAST(PO_Detail.Qty_Remaining AS VARCHAR) + ' units late)' AS Action_Detail,
    'TODAY' AS Recommended_Deadline,
    'MEDIUM' AS Business_Impact,
    PO_Detail.Client_ID

FROM dbo.Rolyat_PO_Detail PO_Detail
INNER JOIN (
    SELECT ITEMNMBR, Client_ID, Expected_Date
    FROM dbo.ETB2_PAB_EventLedger_v1
    WHERE Event_Type = 'PO_RECEIPT'
) Events ON PO_Detail.ITEMNMBR = Events.ITEMNMBR
WHERE Events.Expected_Date < GETDATE()
  AND PO_Detail.Qty_Received < PO_Detail.Qty_Ordered
