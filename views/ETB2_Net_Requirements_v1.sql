/*
===============================================================================
View: dbo.ETB2_Net_Requirements_v1
Description: Net requirements calculation with safety stock consideration
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - dbo.ETB2_Config_Engine_v1 (configuration engine)
   - dbo.ETB2_StockOut_Analysis_v1 (stockout analysis)
   - dbo.ETB2_Final_Ledger_v1 (inventory ledger)

Purpose:
   - Calculates net requirements (how much to order)
   - Incorporates safety stock from config engine
   - Classifies requirement status
   - Assigns requirement priority
   - Calculates days of supply

Business Rules:
   - Net_Requirement_Qty based on ATP balance and safety stock
   - Status classification: CRITICAL_SHORTAGE, BELOW_SAFETY_STOCK, FORECASTED_SHORTAGE, ADEQUATE
   - Priority: 1=critical, 4=adequate
   - Days_Of_Supply = Available_Inventory / Total_Demand

RESTORES:
   - dbo.Rolyat_Net_Requirements_v1 (View 14)

USAGE:
   - Upstream for ETB2_Supply_Chain_Master_v1
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Net_Requirements_v1
AS

WITH SafetyStockConfig AS (
  -- Get safety stock configuration per item
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    COALESCE(Safety_Stock_Days, 7) AS Safety_Stock_Days,
    COALESCE(Safety_Stock_Method, 'DAYS_OF_SUPPLY') AS Safety_Stock_Method
  FROM dbo.ETB2_Config_Engine_v1
  WHERE ITEMNMBR IS NOT NULL
),

InventoryPosition AS (
  -- Get available inventory per item
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    SUM(CASE 
      WHEN Inventory_Status = 'AVAILABLE' 
      THEN Remaining_Qty
      ELSE 0
    END) AS Available_Inventory
  FROM dbo.ETB2_Final_Ledger_v1
  GROUP BY ITEMNMBR, Client_ID, Site_ID
),

DemandAggregation AS (
  -- Aggregate total demand per item
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    SUM(Total_Demand) AS Total_Demand,
    COUNT(DISTINCT Demand_Date) AS Demand_Days
  FROM dbo.ETB2_StockOut_Analysis_v1
  GROUP BY ITEMNMBR, Client_ID, Site_ID
),

RequirementCalculation AS (
  -- Calculate net requirements
  SELECT 
    s.ITEMNMBR,
    s.Client_ID,
    s.Site_ID,
    COALESCE(a.ATP_Balance, 0) AS Current_ATP_Balance,
    COALESCE(a.Unmet_Demand, 0) AS Current_Unmet_Demand,
    COALESCE(i.Available_Inventory, 0) AS Available_Inventory,
    COALESCE(d.Total_Demand, 0) AS Total_Demand,
    COALESCE(d.Demand_Days, 1) AS Demand_Days,
    COALESCE(cfg.Safety_Stock_Days, 7) AS Safety_Stock_Days,
    cfg.Safety_Stock_Method,
    
    -- Calculate safety stock level
    CASE 
      WHEN cfg.Safety_Stock_Method = 'DAYS_OF_SUPPLY' AND d.Demand_Days > 0
      THEN CAST(COALESCE(d.Total_Demand, 0) / d.Demand_Days * COALESCE(cfg.Safety_Stock_Days, 7) AS DECIMAL(18,5))
      ELSE CAST(COALESCE(cfg.Safety_Stock_Days, 7) AS DECIMAL(18,5))
    END AS Safety_Stock_Level,
    
    GETDATE() AS Snapshot_Date
  FROM dbo.ETB2_StockOut_Analysis_v1 s
  LEFT JOIN InventoryPosition i
    ON s.ITEMNMBR = i.ITEMNMBR
   AND s.Client_ID = i.Client_ID
   AND s.Site_ID = i.Site_ID
  LEFT JOIN DemandAggregation d
    ON s.ITEMNMBR = d.ITEMNMBR
   AND s.Client_ID = d.Client_ID
   AND s.Site_ID = d.Site_ID
  LEFT JOIN SafetyStockConfig cfg
    ON s.ITEMNMBR = cfg.ITEMNMBR
   AND s.Client_ID = cfg.Client_ID
   AND s.Site_ID = cfg.Site_ID
),

RequirementStatus AS (
  -- Classify requirement status and calculate net requirement
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Current_ATP_Balance,
    Current_Unmet_Demand,
    Available_Inventory,
    Total_Demand,
    Demand_Days,
    Safety_Stock_Days,
    Safety_Stock_Method,
    Safety_Stock_Level,
    
    -- Net requirement quantity calculation
    CASE 
      WHEN Current_ATP_Balance < 0 
        THEN CAST(ABS(Current_ATP_Balance) + Safety_Stock_Level AS DECIMAL(18,5))
      WHEN Current_ATP_Balance < Safety_Stock_Level 
        THEN CAST(Safety_Stock_Level - Current_ATP_Balance AS DECIMAL(18,5))
      WHEN Current_Unmet_Demand > 0 
        THEN CAST(Current_Unmet_Demand AS DECIMAL(18,5))
      ELSE 0
    END AS Net_Requirement_Qty,
    
    -- Requirement status classification
    CASE 
      WHEN Current_ATP_Balance < 0 
        THEN 'CRITICAL_SHORTAGE'
      WHEN Current_ATP_Balance < Safety_Stock_Level 
        THEN 'BELOW_SAFETY_STOCK'
      WHEN Current_Unmet_Demand > 0 
        THEN 'FORECASTED_SHORTAGE'
      ELSE 'ADEQUATE'
    END AS Requirement_Status,
    
    -- Requirement priority (1=critical, 4=adequate)
    CASE 
      WHEN Current_ATP_Balance < 0 
        THEN 1
      WHEN Current_ATP_Balance < Safety_Stock_Level 
        THEN 2
      WHEN Current_Unmet_Demand > 0 
        THEN 3
      ELSE 4
    END AS Requirement_Priority,
    
    -- Days of supply calculation
    CASE 
      WHEN Total_Demand > 0 AND Demand_Days > 0
      THEN CAST(Available_Inventory * Demand_Days / Total_Demand AS DECIMAL(18,2))
      ELSE 0
    END AS Days_Of_Supply,
    
    Snapshot_Date
  FROM RequirementCalculation
)

-- Final output
SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Current_ATP_Balance,
  Current_Unmet_Demand,
  Available_Inventory,
  Total_Demand,
  Demand_Days,
  Safety_Stock_Days,
  Safety_Stock_Method,
  Safety_Stock_Level,
  Net_Requirement_Qty,
  Requirement_Status,
  Requirement_Priority,
  Days_Of_Supply,
  Snapshot_Date
FROM RequirementStatus
ORDER BY Requirement_Priority ASC, ITEMNMBR, Client_ID, Site_ID;
