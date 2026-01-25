/*
===============================================================================
View: dbo.ETB2_Final_Ledger_v1
Description: Complete inventory ledger across all batch types
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - dbo.ETB2_Inventory_Unified_v1 (unified inventory)
   - dbo.ETB2_Allocation_Engine_v1 (allocation data)

Purpose:
   - Provides complete inventory ledger for all batch types (WC, WFQ, RMQTY)
   - Calculates starting, allocated, and remaining quantities
   - Determines inventory status and expiry risk
   - Calculates utilization percentage per batch

Business Rules:
   - Starting_Qty = QTY_ON_HAND from inventory
   - Remaining_Qty = Starting_Qty - Allocated_Qty
   - Status classification based on remaining qty and hold status
   - Expiry risk tiers: EXPIRED (0), CRITICAL (1-30), HIGH (31-60), MEDIUM (61-90), LOW (>90)

RESTORES:
   - dbo.Rolyat_Final_Ledger_3 (View 09)

USAGE:
   - Upstream for ETB2_StockOut_Analysis_v1
   - Upstream for ETB2_Rebalancing_v1
   - Upstream for ETB2_Net_Requirements_v1
   - Upstream for ETB2_Supply_Chain_Master_v1
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Final_Ledger_v1
AS

WITH InventoryBase AS (
  -- Get all batches from unified inventory
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Batch_ID,
    QTY_ON_HAND AS Starting_Qty,
    Inventory_Type,
    Expiry_Date,
    Receipt_Date,
    Age_Days,
    Is_Eligible_For_Release,
    SortPriority,
    GETDATE() AS Snapshot_Date
  FROM dbo.ETB2_Inventory_Unified_v1
  WHERE QTY_ON_HAND > 0
),

AllocationData AS (
  -- Get total allocated quantities per batch
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Batch_ID,
    SUM(Allocated_Qty) AS Total_Allocated_Qty
  FROM dbo.ETB2_Allocation_Engine_v1
  GROUP BY ITEMNMBR, Client_ID, Site_ID, Batch_ID
),

LedgerCalculations AS (
  -- Join inventory with allocations and calculate ledger
  SELECT 
    i.ITEMNMBR,
    i.Client_ID,
    i.Site_ID,
    i.Batch_ID,
    i.Starting_Qty,
    COALESCE(a.Total_Allocated_Qty, 0) AS Allocated_Qty,
    CAST(i.Starting_Qty - COALESCE(a.Total_Allocated_Qty, 0) AS DECIMAL(18,5)) AS Remaining_Qty,
    i.Inventory_Type,
    i.Expiry_Date,
    i.Receipt_Date,
    i.Age_Days,
    i.Is_Eligible_For_Release,
    i.SortPriority,
    
    -- Days until expiry
    CASE 
      WHEN i.Expiry_Date IS NULL THEN NULL
      ELSE DATEDIFF(DAY, CAST(GETDATE() AS date), CAST(i.Expiry_Date AS date))
    END AS Days_Until_Expiry,
    
    -- Utilization percentage
    CASE 
      WHEN i.Starting_Qty > 0 
      THEN CAST(COALESCE(a.Total_Allocated_Qty, 0) * 100.0 / i.Starting_Qty AS DECIMAL(5,2))
      ELSE 0
    END AS Utilization_Pct,
    
    i.Snapshot_Date
  FROM InventoryBase i
  LEFT JOIN AllocationData a
    ON i.ITEMNMBR = a.ITEMNMBR
   AND i.Client_ID = a.Client_ID
   AND i.Site_ID = a.Site_ID
   AND i.Batch_ID = a.Batch_ID
),

StatusClassification AS (
  -- Classify inventory status
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Batch_ID,
    Starting_Qty,
    Allocated_Qty,
    Remaining_Qty,
    Inventory_Type,
    Expiry_Date,
    Receipt_Date,
    Age_Days,
    Is_Eligible_For_Release,
    SortPriority,
    Days_Until_Expiry,
    Utilization_Pct,
    
    -- Inventory status
    CASE 
      WHEN Remaining_Qty <= 0 THEN 'EXHAUSTED'
      WHEN Is_Eligible_For_Release = 0 THEN 'ON_HOLD'
      WHEN Days_Until_Expiry IS NOT NULL AND Days_Until_Expiry <= 30 THEN 'EXPIRING_SOON'
      ELSE 'AVAILABLE'
    END AS Inventory_Status,
    
    -- Expiry risk tier
    CASE 
      WHEN Days_Until_Expiry IS NULL THEN 'NO_EXPIRY'
      WHEN Days_Until_Expiry <= 0 THEN 'EXPIRED'
      WHEN Days_Until_Expiry <= 30 THEN 'CRITICAL'
      WHEN Days_Until_Expiry <= 60 THEN 'HIGH'
      WHEN Days_Until_Expiry <= 90 THEN 'MEDIUM'
      ELSE 'LOW'
    END AS Expiry_Risk_Tier,
    
    -- Ledger category
    CASE 
      WHEN Remaining_Qty <= 0 THEN 'CONSUMED'
      WHEN Is_Eligible_For_Release = 0 THEN 'HELD'
      WHEN Days_Until_Expiry IS NOT NULL AND Days_Until_Expiry <= 30 THEN 'EXPIRING'
      ELSE 'AVAILABLE'
    END AS Ledger_Category,
    
    Snapshot_Date
  FROM LedgerCalculations
)

-- Final output
SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Batch_ID,
  Starting_Qty,
  Allocated_Qty,
  Remaining_Qty,
  Inventory_Type,
  Expiry_Date,
  Receipt_Date,
  Age_Days,
  Is_Eligible_For_Release,
  SortPriority,
  Days_Until_Expiry,
  Utilization_Pct,
  Inventory_Status,
  Expiry_Risk_Tier,
  Ledger_Category,
  Snapshot_Date
FROM StatusClassification
ORDER BY ITEMNMBR, Client_ID, Site_ID, SortPriority, Expiry_Date ASC;
