/*
===============================================================================
View: dbo.ETB2_Allocation_Engine_v1
Description: FEFO allocation engine for WC batches against demand
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - dbo.ETB2_Inventory_Unified_v1 (unified inventory view)
   - dbo.Rolyat_Cleaned_Base_Demand_1 (cleaned demand data)

Purpose:
   - Implements FEFO (First Expiry First Out) allocation logic
   - Allocates WC batches sequentially against demand
   - Calculates running balance and allocation status
   - Determines remaining demand after allocation

Business Rules:
   - Only allocates eligible WC batches (Is_Eligible_For_Release = 1)
   - Sorts by Expiry_Date ASC, SortPriority ASC (FEFO)
   - Allocates demand sequentially against batches
   - Tracks allocation status per batch

RESTORES:
   - dbo.Rolyat_WC_Allocation_Effective_2 (View 08)

USAGE:
   - Upstream for ETB2_Final_Ledger_v1
   - Upstream for ETB2_StockOut_Analysis_v1
   - Upstream for ETB2_Rebalancing_v1
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Allocation_Engine_v1
AS

WITH DemandBase AS (
  -- Get cleaned demand from view 04
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    DUEDATE AS Demand_Date,
    Base_Demand,
    SortPriority AS Demand_SortPriority,
    GETDATE() AS Snapshot_Date
  FROM dbo.Rolyat_Cleaned_Base_Demand_1
  WHERE Base_Demand > 0
    AND DUEDATE IS NOT NULL
),

EligibleBatches AS (
  -- Get eligible WC batches sorted by FEFO
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Batch_ID,
    QTY_ON_HAND,
    Inventory_Type,
    Expiry_Date,
    Receipt_Date,
    Is_Eligible_For_Release,
    SortPriority,
    ROW_NUMBER() OVER (
      PARTITION BY ITEMNMBR, Client_ID, Site_ID 
      ORDER BY Expiry_Date ASC, SortPriority ASC, Batch_ID ASC
    ) AS Batch_Sequence
  FROM dbo.ETB2_Inventory_Unified_v1
  WHERE Inventory_Type = 'WC_BATCH'
    AND Is_Eligible_For_Release = 1
    AND QTY_ON_HAND > 0
),

DemandSequence AS (
  -- Sequence demand records for allocation
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Demand_Date,
    Base_Demand,
    Demand_SortPriority,
    ROW_NUMBER() OVER (
      PARTITION BY ITEMNMBR, Client_ID, Site_ID 
      ORDER BY Demand_Date ASC, Demand_SortPriority ASC
    ) AS Demand_Sequence,
    Snapshot_Date
  FROM DemandBase
),

AllocationCrossJoin AS (
  -- Cross join batches with demand for allocation matching
  SELECT 
    d.ITEMNMBR,
    d.Client_ID,
    d.Site_ID,
    d.Demand_Date,
    d.Base_Demand,
    d.Demand_Sequence,
    b.Batch_ID,
    b.QTY_ON_HAND,
    b.Expiry_Date,
    b.Receipt_Date,
    b.Batch_Sequence,
    d.Snapshot_Date
  FROM DemandSequence d
  LEFT JOIN EligibleBatches b
    ON d.ITEMNMBR = b.ITEMNMBR
   AND d.Client_ID = b.Client_ID
   AND d.Site_ID = b.Site_ID
),

AllocationLogic AS (
  -- Calculate allocation per batch-demand pair
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Batch_ID,
    Demand_Date,
    Base_Demand,
    Batch_Sequence,
    Demand_Sequence,
    QTY_ON_HAND,
    Expiry_Date,
    Receipt_Date,
    
    -- Running balance: sum of all prior allocations for this batch
    SUM(CASE 
      WHEN Batch_Sequence IS NOT NULL 
      THEN CAST(LEAST(CAST(Base_Demand AS FLOAT), CAST(QTY_ON_HAND AS FLOAT)) AS DECIMAL(18,5))
      ELSE 0 
    END) OVER (
      PARTITION BY ITEMNMBR, Client_ID, Site_ID, Batch_ID 
      ORDER BY Demand_Sequence ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS Prior_Allocation_Sum,
    
    -- Allocated quantity for this demand against this batch
    CASE 
      WHEN Batch_Sequence IS NOT NULL 
      THEN CAST(LEAST(
        CAST(Base_Demand AS FLOAT),
        CAST(QTY_ON_HAND AS FLOAT) - COALESCE(
          SUM(CASE 
            WHEN Batch_Sequence IS NOT NULL 
            THEN CAST(LEAST(CAST(Base_Demand AS FLOAT), CAST(QTY_ON_HAND AS FLOAT)) AS FLOAT)
            ELSE 0 
          END) OVER (
            PARTITION BY ITEMNMBR, Client_ID, Site_ID, Batch_ID 
            ORDER BY Demand_Sequence ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
          ), 0
        )
      ) AS DECIMAL(18,5))
      ELSE 0 
    END AS Allocated_Qty,
    
    Snapshot_Date
  FROM AllocationCrossJoin
),

AllocationStatus AS (
  -- Determine allocation status per batch
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Batch_ID,
    Demand_Date,
    Base_Demand,
    Batch_Sequence,
    Demand_Sequence,
    QTY_ON_HAND,
    Expiry_Date,
    Receipt_Date,
    Prior_Allocation_Sum,
    Allocated_Qty,
    
    -- Total allocated for this batch across all demands
    SUM(Allocated_Qty) OVER (
      PARTITION BY ITEMNMBR, Client_ID, Site_ID, Batch_ID
    ) AS Total_Allocated_Per_Batch,
    
    -- Remaining demand after this allocation
    CAST(Base_Demand - Allocated_Qty AS DECIMAL(18,5)) AS Remaining_Demand,
    
    -- Allocation status
    CASE 
      WHEN Allocated_Qty >= Base_Demand THEN 'FULLY_ALLOCATED'
      WHEN Allocated_Qty > 0 AND Allocated_Qty < Base_Demand THEN 'PARTIALLY_ALLOCATED'
      ELSE 'NOT_ALLOCATED'
    END AS Allocation_Status,
    
    Snapshot_Date
  FROM AllocationLogic
)

-- Final output
SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Batch_ID,
  Demand_Date,
  Base_Demand,
  Batch_Sequence,
  Demand_Sequence,
  QTY_ON_HAND,
  Expiry_Date,
  Receipt_Date,
  Prior_Allocation_Sum,
  Allocated_Qty,
  Total_Allocated_Per_Batch,
  Remaining_Demand,
  Allocation_Status,
  Snapshot_Date
FROM AllocationStatus
WHERE Batch_Sequence IS NOT NULL
ORDER BY ITEMNMBR, Client_ID, Site_ID, Batch_Sequence, Demand_Sequence;
