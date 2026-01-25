/*
===============================================================================
View: dbo.ETB2_Supply_Chain_Master_v1
Description: Master integration view combining all ETB2 supply chain views
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - dbo.ETB2_StockOut_Analysis_v1 (demand baseline)
   - dbo.ETB2_Final_Ledger_v1 (inventory position)
   - dbo.ETB2_Net_Requirements_v1 (requirements)
   - dbo.ETB2_Unit_Price_v1 (pricing)
   - dbo.ETB2_PO_Detail_v1 (PO tracking)
   - dbo.ETB2_Rebalancing_v1 (rebalancing opportunities)

Purpose:
   - Provides single comprehensive view of supply chain per item/date/site
   - Combines demand, inventory, requirements, pricing, PO, and rebalancing
   - Calculates extended value metrics
   - Enables holistic supply chain analysis

Business Rules:
   - Demand baseline from StockOut_Analysis
   - Inventory position from Final_Ledger
   - Requirements from Net_Requirements
   - Pricing from Unit_Price
   - PO tracking from PO_Detail
   - Rebalancing opportunities from Rebalancing
   - Extended values calculated from base metrics

USAGE:
   - Master reporting view
   - Supply chain dashboards
   - Executive summaries
   - Integrated analysis
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Supply_Chain_Master_v1
AS

WITH DemandBase AS (
  -- Start with demand baseline
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
  FROM dbo.ETB2_StockOut_Analysis_v1
),

InventoryJoin AS (
  -- Join inventory position
  SELECT 
    d.ITEMNMBR,
    d.Client_ID,
    d.Site_ID,
    d.Demand_Date,
    d.Total_Demand,
    d.Total_Allocated,
    d.ATP_Balance,
    d.Unmet_Demand,
    d.Available_Alternate_Qty,
    d.Effective_ATP_Balance,
    d.Risk_Level,
    d.Recommended_Action,
    d.Action_Priority,
    
    -- Inventory metrics
    SUM(CASE WHEN inv.Inventory_Status = 'AVAILABLE' THEN inv.Remaining_Qty ELSE 0 END) AS Available_Inventory,
    SUM(inv.Starting_Qty) AS Total_Starting_Qty,
    SUM(inv.Allocated_Qty) AS Total_Allocated_Qty,
    SUM(inv.Remaining_Qty) AS Total_Remaining_Qty,
    COUNT(DISTINCT inv.Batch_ID) AS Batch_Count,
    MIN(inv.Days_Until_Expiry) AS Min_Days_Until_Expiry,
    MAX(inv.Days_Until_Expiry) AS Max_Days_Until_Expiry,
    
    d.Snapshot_Date
  FROM DemandBase d
  LEFT JOIN dbo.ETB2_Final_Ledger_v1 inv
    ON d.ITEMNMBR = inv.ITEMNMBR
   AND d.Client_ID = inv.Client_ID
   AND d.Site_ID = inv.Site_ID
  GROUP BY 
    d.ITEMNMBR, d.Client_ID, d.Site_ID, d.Demand_Date,
    d.Total_Demand, d.Total_Allocated, d.ATP_Balance, d.Unmet_Demand,
    d.Available_Alternate_Qty, d.Effective_ATP_Balance, d.Risk_Level,
    d.Recommended_Action, d.Action_Priority, d.Snapshot_Date
),

RequirementsJoin AS (
  -- Join net requirements
  SELECT 
    i.ITEMNMBR,
    i.Client_ID,
    i.Site_ID,
    i.Demand_Date,
    i.Total_Demand,
    i.Total_Allocated,
    i.ATP_Balance,
    i.Unmet_Demand,
    i.Available_Alternate_Qty,
    i.Effective_ATP_Balance,
    i.Risk_Level,
    i.Recommended_Action,
    i.Action_Priority,
    i.Available_Inventory,
    i.Total_Starting_Qty,
    i.Total_Allocated_Qty,
    i.Total_Remaining_Qty,
    i.Batch_Count,
    i.Min_Days_Until_Expiry,
    i.Max_Days_Until_Expiry,
    
    -- Requirements metrics
    COALESCE(nr.Net_Requirement_Qty, 0) AS Net_Requirement_Qty,
    COALESCE(nr.Requirement_Status, 'ADEQUATE') AS Requirement_Status,
    COALESCE(nr.Requirement_Priority, 4) AS Requirement_Priority,
    COALESCE(nr.Days_Of_Supply, 0) AS Days_Of_Supply,
    COALESCE(nr.Safety_Stock_Level, 0) AS Safety_Stock_Level,
    
    i.Snapshot_Date
  FROM InventoryJoin i
  LEFT JOIN dbo.ETB2_Net_Requirements_v1 nr
    ON i.ITEMNMBR = nr.ITEMNMBR
   AND i.Client_ID = nr.Client_ID
   AND i.Site_ID = nr.Site_ID
),

PricingJoin AS (
  -- Join pricing data
  SELECT 
    r.ITEMNMBR,
    r.Client_ID,
    r.Site_ID,
    r.Demand_Date,
    r.Total_Demand,
    r.Total_Allocated,
    r.ATP_Balance,
    r.Unmet_Demand,
    r.Available_Alternate_Qty,
    r.Effective_ATP_Balance,
    r.Risk_Level,
    r.Recommended_Action,
    r.Action_Priority,
    r.Available_Inventory,
    r.Total_Starting_Qty,
    r.Total_Allocated_Qty,
    r.Total_Remaining_Qty,
    r.Batch_Count,
    r.Min_Days_Until_Expiry,
    r.Max_Days_Until_Expiry,
    r.Net_Requirement_Qty,
    r.Requirement_Status,
    r.Requirement_Priority,
    r.Days_Of_Supply,
    r.Safety_Stock_Level,
    
    -- Pricing metrics
    COALESCE(p.Effective_Unit_Price, 0) AS Effective_Unit_Price,
    COALESCE(p.List_Price, 0) AS List_Price,
    COALESCE(p.Current_Cost, 0) AS Current_Cost,
    COALESCE(p.Standard_Cost, 0) AS Standard_Cost,
    COALESCE(p.Gross_Margin_Pct, 0) AS Gross_Margin_Pct,
    
    r.Snapshot_Date
  FROM RequirementsJoin r
  LEFT JOIN dbo.ETB2_Unit_Price_v1 p
    ON r.ITEMNMBR = p.ITEMNMBR
   AND r.Site_ID = p.Site_ID
),

POJoin AS (
  -- Join PO data
  SELECT 
    p.ITEMNMBR,
    p.Client_ID,
    p.Site_ID,
    p.Demand_Date,
    p.Total_Demand,
    p.Total_Allocated,
    p.ATP_Balance,
    p.Unmet_Demand,
    p.Available_Alternate_Qty,
    p.Effective_ATP_Balance,
    p.Risk_Level,
    p.Recommended_Action,
    p.Action_Priority,
    p.Available_Inventory,
    p.Total_Starting_Qty,
    p.Total_Allocated_Qty,
    p.Total_Remaining_Qty,
    p.Batch_Count,
    p.Min_Days_Until_Expiry,
    p.Max_Days_Until_Expiry,
    p.Net_Requirement_Qty,
    p.Requirement_Status,
    p.Requirement_Priority,
    p.Days_Of_Supply,
    p.Safety_Stock_Level,
    p.Effective_Unit_Price,
    p.List_Price,
    p.Current_Cost,
    p.Standard_Cost,
    p.Gross_Margin_Pct,
    
    -- PO metrics
    SUM(po.Quantity_Remaining) AS PO_Quantity_Remaining,
    SUM(CASE WHEN po.Delivery_Status = 'PAST_DUE' THEN po.Quantity_Remaining ELSE 0 END) AS PO_Past_Due_Qty,
    SUM(CASE WHEN po.Delivery_Status = 'DUE_SOON' THEN po.Quantity_Remaining ELSE 0 END) AS PO_Due_Soon_Qty,
    COUNT(DISTINCT po.PONUMBER) AS PO_Count,
    
    p.Snapshot_Date
  FROM PricingJoin p
  LEFT JOIN dbo.ETB2_PO_Detail_v1 po
    ON p.ITEMNMBR = po.ITEMNMBR
  GROUP BY 
    p.ITEMNMBR, p.Client_ID, p.Site_ID, p.Demand_Date,
    p.Total_Demand, p.Total_Allocated, p.ATP_Balance, p.Unmet_Demand,
    p.Available_Alternate_Qty, p.Effective_ATP_Balance, p.Risk_Level,
    p.Recommended_Action, p.Action_Priority, p.Available_Inventory,
    p.Total_Starting_Qty, p.Total_Allocated_Qty, p.Total_Remaining_Qty,
    p.Batch_Count, p.Min_Days_Until_Expiry, p.Max_Days_Until_Expiry,
    p.Net_Requirement_Qty, p.Requirement_Status, p.Requirement_Priority,
    p.Days_Of_Supply, p.Safety_Stock_Level, p.Effective_Unit_Price,
    p.List_Price, p.Current_Cost, p.Standard_Cost, p.Gross_Margin_Pct,
    p.Snapshot_Date
),

RebalancingJoin AS (
  -- Join rebalancing opportunities
  SELECT 
    po.ITEMNMBR,
    po.Client_ID,
    po.Site_ID,
    po.Demand_Date,
    po.Total_Demand,
    po.Total_Allocated,
    po.ATP_Balance,
    po.Unmet_Demand,
    po.Available_Alternate_Qty,
    po.Effective_ATP_Balance,
    po.Risk_Level,
    po.Recommended_Action,
    po.Action_Priority,
    po.Available_Inventory,
    po.Total_Starting_Qty,
    po.Total_Allocated_Qty,
    po.Total_Remaining_Qty,
    po.Batch_Count,
    po.Min_Days_Until_Expiry,
    po.Max_Days_Until_Expiry,
    po.Net_Requirement_Qty,
    po.Requirement_Status,
    po.Requirement_Priority,
    po.Days_Of_Supply,
    po.Safety_Stock_Level,
    po.Effective_Unit_Price,
    po.List_Price,
    po.Current_Cost,
    po.Standard_Cost,
    po.Gross_Margin_Pct,
    po.PO_Quantity_Remaining,
    po.PO_Past_Due_Qty,
    po.PO_Due_Soon_Qty,
    po.PO_Count,
    
    -- Rebalancing metrics
    SUM(rb.Recommended_Transfer_Qty) AS Rebalancing_Transfer_Qty,
    MIN(rb.Transfer_Priority) AS Rebalancing_Priority,
    MAX(CASE WHEN rb.Rebalancing_Type = 'URGENT_TRANSFER' THEN 1 ELSE 0 END) AS Has_Urgent_Rebalancing,
    
    po.Snapshot_Date
  FROM POJoin po
  LEFT JOIN dbo.ETB2_Rebalancing_v1 rb
    ON po.ITEMNMBR = rb.ITEMNMBR
   AND po.Client_ID = rb.Client_ID
   AND po.Site_ID = rb.Site_ID
  GROUP BY 
    po.ITEMNMBR, po.Client_ID, po.Site_ID, po.Demand_Date,
    po.Total_Demand, po.Total_Allocated, po.ATP_Balance, po.Unmet_Demand,
    po.Available_Alternate_Qty, po.Effective_ATP_Balance, po.Risk_Level,
    po.Recommended_Action, po.Action_Priority, po.Available_Inventory,
    po.Total_Starting_Qty, po.Total_Allocated_Qty, po.Total_Remaining_Qty,
    po.Batch_Count, po.Min_Days_Until_Expiry, po.Max_Days_Until_Expiry,
    po.Net_Requirement_Qty, po.Requirement_Status, po.Requirement_Priority,
    po.Days_Of_Supply, po.Safety_Stock_Level, po.Effective_Unit_Price,
    po.List_Price, po.Current_Cost, po.Standard_Cost, po.Gross_Margin_Pct,
    po.PO_Quantity_Remaining, po.PO_Past_Due_Qty, po.PO_Due_Soon_Qty, po.PO_Count,
    po.Snapshot_Date
),

ExtendedValues AS (
  -- Calculate extended value metrics
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
    Available_Inventory,
    Total_Starting_Qty,
    Total_Allocated_Qty,
    Total_Remaining_Qty,
    Batch_Count,
    Min_Days_Until_Expiry,
    Max_Days_Until_Expiry,
    Net_Requirement_Qty,
    Requirement_Status,
    Requirement_Priority,
    Days_Of_Supply,
    Safety_Stock_Level,
    Effective_Unit_Price,
    List_Price,
    Current_Cost,
    Standard_Cost,
    Gross_Margin_Pct,
    PO_Quantity_Remaining,
    PO_Past_Due_Qty,
    PO_Due_Soon_Qty,
    PO_Count,
    Rebalancing_Transfer_Qty,
    Rebalancing_Priority,
    Has_Urgent_Rebalancing,
    
    -- Extended value calculations
    CAST(Total_Demand * Effective_Unit_Price AS DECIMAL(18,2)) AS Gross_Demand_Value,
    CAST(Unmet_Demand * Effective_Unit_Price AS DECIMAL(18,2)) AS Stockout_Risk_Value,
    CAST(Net_Requirement_Qty * Standard_Cost AS DECIMAL(18,2)) AS Net_Requirement_Cost,
    CAST(Available_Inventory * Effective_Unit_Price AS DECIMAL(18,2)) AS Available_Inventory_Value,
    
    Snapshot_Date
  FROM RebalancingJoin
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
  Available_Inventory,
  Total_Starting_Qty,
  Total_Allocated_Qty,
  Total_Remaining_Qty,
  Batch_Count,
  Min_Days_Until_Expiry,
  Max_Days_Until_Expiry,
  Net_Requirement_Qty,
  Requirement_Status,
  Requirement_Priority,
  Days_Of_Supply,
  Safety_Stock_Level,
  Effective_Unit_Price,
  List_Price,
  Current_Cost,
  Standard_Cost,
  Gross_Margin_Pct,
  PO_Quantity_Remaining,
  PO_Past_Due_Qty,
  PO_Due_Soon_Qty,
  PO_Count,
  Rebalancing_Transfer_Qty,
  Rebalancing_Priority,
  Has_Urgent_Rebalancing,
  Gross_Demand_Value,
  Stockout_Risk_Value,
  Net_Requirement_Cost,
  Available_Inventory_Value,
  Snapshot_Date
FROM ExtendedValues
ORDER BY ITEMNMBR, Client_ID, Site_ID, Demand_Date, Action_Priority DESC;
