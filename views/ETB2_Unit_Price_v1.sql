/*
===============================================================================
View: dbo.ETB2_Unit_Price_v1
Description: Unit pricing with tier logic and effective price calculation
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - GP tables IV00108 (Item Price List)
   - GP tables IV00101 (Item Master)

Purpose:
   - Provides unit pricing with tier classification
   - Calculates effective price using fallback hierarchy
   - Determines price tier (RETAIL, WHOLESALE, DISTRIBUTOR, COST_PLUS)
   - Calculates gross margin percentage
   - Supports multi-currency and multi-location

Business Rules:
   - Effective_Unit_Price hierarchy: List_Price > Current_Cost > Standard_Cost
   - Price tier mapping: RETAIL=1, WHOLESALE=2, DISTRIBUTOR=3, COST_PLUS=4
   - Gross_Margin_Pct = (List_Price - Current_Cost) / List_Price
   - Includes UOM, Currency, Location information

RESTORES:
   - dbo.Rolyat_Unit_Price_4 (View 07)

USAGE:
   - Upstream for ETB2_Supply_Chain_Master_v1
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Unit_Price_v1
AS

WITH ItemPricing AS (
  -- Get item pricing data from price list and item master
  SELECT 
    p.ITEMNMBR,
    p.LOCNCODE AS Site_ID,
    p.PRCLEVEL AS Price_Level,
    p.UNITPRCE AS List_Price,
    i.CURRCOST AS Current_Cost,
    i.STNDCOST AS Standard_Cost,
    i.UOMSCHDL AS UOM,
    i.CURNCYID AS Currency,
    GETDATE() AS Snapshot_Date
  FROM IV00108 p WITH (NOLOCK)
  LEFT JOIN IV00101 i WITH (NOLOCK)
    ON p.ITEMNMBR = i.ITEMNMBR
  WHERE p.UNITPRCE > 0
     OR i.CURRCOST > 0
     OR i.STNDCOST > 0
),

EffectivePricing AS (
  -- Calculate effective unit price using fallback hierarchy
  SELECT 
    ITEMNMBR,
    Site_ID,
    Price_Level,
    List_Price,
    Current_Cost,
    Standard_Cost,
    UOM,
    Currency,
    
    -- Effective unit price (fallback hierarchy)
    CASE 
      WHEN List_Price > 0 THEN CAST(List_Price AS DECIMAL(18,5))
      WHEN Current_Cost > 0 THEN CAST(Current_Cost AS DECIMAL(18,5))
      WHEN Standard_Cost > 0 THEN CAST(Standard_Cost AS DECIMAL(18,5))
      ELSE 0
    END AS Effective_Unit_Price,
    
    -- Price tier classification
    CASE 
      WHEN Price_Level = 'RETAIL' THEN 1
      WHEN Price_Level = 'WHOLESALE' THEN 2
      WHEN Price_Level = 'DISTRIBUTOR' THEN 3
      WHEN Price_Level = 'COST_PLUS' THEN 4
      ELSE 5
    END AS Price_Tier,
    
    -- Gross margin percentage
    CASE 
      WHEN List_Price > 0 AND Current_Cost > 0
      THEN CAST((List_Price - Current_Cost) * 100.0 / List_Price AS DECIMAL(5,2))
      WHEN List_Price > 0
      THEN CAST(100.0 AS DECIMAL(5,2))
      ELSE 0
    END AS Gross_Margin_Pct,
    
    Snapshot_Date
  FROM ItemPricing
)

-- Final output
SELECT 
  ITEMNMBR,
  Site_ID,
  Price_Level,
  List_Price,
  Current_Cost,
  Standard_Cost,
  Effective_Unit_Price,
  Price_Tier,
  Gross_Margin_Pct,
  UOM,
  Currency,
  Snapshot_Date
FROM EffectivePricing
ORDER BY ITEMNMBR, Site_ID, Price_Tier;
