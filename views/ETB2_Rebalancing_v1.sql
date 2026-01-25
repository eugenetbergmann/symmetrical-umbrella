/*
===============================================================================
View: dbo.ETB2_Rebalancing_v1
Description: Inventory rebalancing recommendations for expiring stock
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - dbo.ETB2_Final_Ledger_v1 (inventory ledger)
   - dbo.ETB2_StockOut_Analysis_v1 (stockout analysis)

Purpose:
   - Matches expiring inventory with stockout demand
   - Generates rebalancing recommendations
   - Prioritizes transfers by urgency
   - Assesses business impact

Business Rules:
   - Identifies expiring batches (Days_Until_Expiry <= 90)
   - Identifies stockout items (Risk_Level IN CRITICAL/HIGH/MEDIUM)
   - Calculates recommended transfer quantity
   - Prioritizes by expiry urgency and demand risk

RESTORES:
   - dbo.Rolyat_Rebalancing_Layer (View 11)

USAGE:
   - Upstream for ETB2_Supply_Chain_Master_v1
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Rebalancing_v1
AS

WITH ExpiringInventory AS (
  -- Identify expiring batches with available quantity
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Batch_ID,
    Remaining_Qty,
    Days_Until_Expiry,
    Inventory_Status,
    Expiry_Risk_Tier,
    GETDATE() AS Snapshot_Date
  FROM dbo.ETB2_Final_Ledger_v1
  WHERE Days_Until_Expiry IS NOT NULL
    AND Days_Until_Expiry <= 90
    AND Days_Until_Expiry > 0
    AND Remaining_Qty > 0
    AND Inventory_Status NOT IN ('EXHAUSTED', 'ON_HOLD')
),

StockoutDemand AS (
  -- Identify items with stockout risk
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Risk_Level,
    Unmet_Demand,
    Recommended_Action
  FROM dbo.ETB2_StockOut_Analysis_v1
  WHERE Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK', 'MEDIUM_RISK')
    AND Unmet_Demand > 0
),

RebalancingMatches AS (
  -- Cross-match expiring inventory with stockout demand
  SELECT 
    e.ITEMNMBR,
    e.Client_ID,
    e.Site_ID,
    e.Batch_ID,
    e.Remaining_Qty,
    e.Days_Until_Expiry,
    e.Expiry_Risk_Tier,
    s.Risk_Level,
    s.Unmet_Demand,
    
    -- Recommended transfer quantity
    CAST(LEAST(e.Remaining_Qty, s.Unmet_Demand) AS DECIMAL(18,5)) AS Recommended_Transfer_Qty,
    
    -- Transfer priority based on expiry and risk
    CASE 
      WHEN e.Days_Until_Expiry <= 30 AND s.Risk_Level = 'CRITICAL_STOCKOUT' 
        THEN 1
      WHEN e.Days_Until_Expiry <= 60 AND s.Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK') 
        THEN 2
      WHEN e.Days_Until_Expiry <= 90 AND s.Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK', 'MEDIUM_RISK') 
        THEN 3
      ELSE 4
    END AS Transfer_Priority,
    
    -- Rebalancing recommendation type
    CASE 
      WHEN e.Days_Until_Expiry <= 30 AND s.Risk_Level = 'CRITICAL_STOCKOUT' 
        THEN 'URGENT_TRANSFER'
      WHEN e.Days_Until_Expiry <= 60 AND s.Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK') 
        THEN 'EXPEDITE_TRANSFER'
      WHEN e.Days_Until_Expiry <= 90 AND s.Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK', 'MEDIUM_RISK') 
        THEN 'PLANNED_TRANSFER'
      ELSE 'MONITOR'
    END AS Rebalancing_Type,
    
    -- Business impact assessment
    CASE 
      WHEN e.Days_Until_Expiry <= 60 AND s.Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK') 
        THEN 'HIGH'
      WHEN e.Days_Until_Expiry <= 90 AND s.Risk_Level = 'MEDIUM_RISK' 
        THEN 'MEDIUM'
      ELSE 'LOW'
    END AS Business_Impact,
    
    e.Snapshot_Date
  FROM ExpiringInventory e
  INNER JOIN StockoutDemand s
    ON e.ITEMNMBR = s.ITEMNMBR
   AND e.Client_ID = s.Client_ID
   AND e.Site_ID = s.Site_ID
)

-- Final output
SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Batch_ID,
  Remaining_Qty,
  Days_Until_Expiry,
  Expiry_Risk_Tier,
  Risk_Level,
  Unmet_Demand,
  Recommended_Transfer_Qty,
  Transfer_Priority,
  Rebalancing_Type,
  Business_Impact,
  Snapshot_Date
FROM RebalancingMatches
ORDER BY Transfer_Priority ASC, Days_Until_Expiry ASC, ITEMNMBR, Client_ID, Site_ID;
