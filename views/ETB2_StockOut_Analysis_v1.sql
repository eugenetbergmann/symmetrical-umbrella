/*
===============================================================================
View: dbo.ETB2_StockOut_Analysis_v1
Description: ATP and stockout risk analysis with alternate stock evaluation
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - dbo.ETB2_Allocation_Engine_v1 (allocation data)
   - dbo.ETB2_Final_Ledger_v1 (inventory ledger)
   - dbo.Rolyat_Cleaned_Base_Demand_1 (demand data)

Purpose:
   - Calculates ATP (Available To Promise) balance
   - Classifies stockout risk (CRITICAL, HIGH, MEDIUM, HEALTHY)
   - Evaluates alternate stock availability (WFQ/RMQTY)
   - Recommends actions based on risk level
   - Assigns action priority (1=critical, 5=healthy)

Business Rules:
   - ATP_Balance = Total_Allocated - Total_Demand
   - Effective_ATP = ATP_Balance + Available_Alternate_Qty
   - Risk classification based on ATP and alternate availability
   - Action priority inversely correlates with ATP balance

RESTORES:
   - dbo.Rolyat_StockOut_Analysis_v2 (View 10)

USAGE:
   - Upstream for ETB2_Rebalancing_v1
   - Upstream for ETB2_Net_Requirements_v1
   - Upstream for ETB2_Supply_Chain_Master_v1
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_StockOut_Analysis_v1
AS

WITH DemandAggregation AS (
  -- Aggregate demand by item/date/site
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Demand_Date,
    SUM(Base_Demand) AS Total_Demand,
    COUNT(*) AS Demand_Line_Count,
    GETDATE() AS Snapshot_Date
  FROM dbo.Rolyat_Cleaned_Base_Demand_1
  WHERE Base_Demand > 0
    AND Demand_Date IS NOT NULL
  GROUP BY ITEMNMBR, Client_ID, Site_ID, Demand_Date
),

AllocationAggregation AS (
  -- Aggregate allocations by item/date/site
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Demand_Date,
    SUM(Allocated_Qty) AS Total_Allocated,
    COUNT(DISTINCT Batch_ID) AS Batch_Count
  FROM dbo.ETB2_Allocation_Engine_v1
  GROUP BY ITEMNMBR, Client_ID, Site_ID, Demand_Date
),

ATPCalculation AS (
  -- Calculate ATP balance
  SELECT 
    d.ITEMNMBR,
    d.Client_ID,
    d.Site_ID,
    d.Demand_Date,
    d.Total_Demand,
    COALESCE(a.Total_Allocated, 0) AS Total_Allocated,
    CAST(COALESCE(a.Total_Allocated, 0) - d.Total_Demand AS DECIMAL(18,5)) AS ATP_Balance,
    CAST(d.Total_Demand - COALESCE(a.Total_Allocated, 0) AS DECIMAL(18,5)) AS Unmet_Demand,
    d.Snapshot_Date
  FROM DemandAggregation d
  LEFT JOIN AllocationAggregation a
    ON d.ITEMNMBR = a.ITEMNMBR
   AND d.Client_ID = a.Client_ID
   AND d.Site_ID = a.Site_ID
   AND d.Demand_Date = a.Demand_Date
),

AlternateStockAvailability AS (
  -- Get available alternate stock (WFQ/RMQTY)
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    SUM(CASE 
      WHEN Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH') 
        AND Is_Eligible_For_Release = 1 
        AND Remaining_Qty > 0
      THEN Remaining_Qty
      ELSE 0
    END) AS Available_Alternate_Qty
  FROM dbo.ETB2_Final_Ledger_v1
  GROUP BY ITEMNMBR, Client_ID, Site_ID
),

RiskClassification AS (
  -- Classify stockout risk
  SELECT 
    a.ITEMNMBR,
    a.Client_ID,
    a.Site_ID,
    a.Demand_Date,
    a.Total_Demand,
    a.Total_Allocated,
    a.ATP_Balance,
    a.Unmet_Demand,
    COALESCE(alt.Available_Alternate_Qty, 0) AS Available_Alternate_Qty,
    CAST(a.ATP_Balance + COALESCE(alt.Available_Alternate_Qty, 0) AS DECIMAL(18,5)) AS Effective_ATP_Balance,
    
    -- Risk level classification
    CASE 
      WHEN a.ATP_Balance <= 0 AND COALESCE(alt.Available_Alternate_Qty, 0) <= 0 
        THEN 'CRITICAL_STOCKOUT'
      WHEN a.ATP_Balance <= 0 AND COALESCE(alt.Available_Alternate_Qty, 0) > 0 
        THEN 'HIGH_RISK'
      WHEN a.ATP_Balance BETWEEN 1 AND 49 
        THEN 'MEDIUM_RISK'
      WHEN a.ATP_Balance BETWEEN 50 AND 99 
        THEN 'LOW_RISK'
      ELSE 'HEALTHY'
    END AS Risk_Level,
    
    -- Recommended action
    CASE 
      WHEN a.ATP_Balance <= 0 AND COALESCE(alt.Available_Alternate_Qty, 0) <= 0 
        THEN 'URGENT_PURCHASE'
      WHEN a.ATP_Balance <= 0 AND COALESCE(alt.Available_Alternate_Qty, 0) > 0 
        THEN 'RELEASE_ALTERNATE_STOCK'
      WHEN a.ATP_Balance BETWEEN 1 AND 49 
        THEN 'EXPEDITE_OPEN_POS'
      ELSE 'MONITOR'
    END AS Recommended_Action,
    
    -- Action priority (1=critical, 5=healthy)
    CASE 
      WHEN a.ATP_Balance <= 0 AND COALESCE(alt.Available_Alternate_Qty, 0) <= 0 
        THEN 1
      WHEN a.ATP_Balance <= 0 AND COALESCE(alt.Available_Alternate_Qty, 0) > 0 
        THEN 2
      WHEN a.ATP_Balance BETWEEN 1 AND 49 
        THEN 3
      WHEN a.ATP_Balance BETWEEN 50 AND 99 
        THEN 4
      ELSE 5
    END AS Action_Priority,
    
    a.Snapshot_Date
  FROM ATPCalculation a
  LEFT JOIN AlternateStockAvailability alt
    ON a.ITEMNMBR = alt.ITEMNMBR
   AND a.Client_ID = alt.Client_ID
   AND a.Site_ID = alt.Site_ID
)

-- Final output
SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Demand_Date,
  Total_Demand,
  Total_Allocated,
  ATP_Balance,
  Unmet_Demand,
  Available_Alternate_Qty,
  Effective_ATP_Balance,
  Risk_Level,
  Recommended_Action,
  Action_Priority,
  Snapshot_Date
FROM RiskClassification
ORDER BY ITEMNMBR, Client_ID, Site_ID, Demand_Date, Action_Priority DESC;
