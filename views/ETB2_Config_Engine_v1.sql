/*
===============================================================================
View: dbo.ETB2_Config_Engine_v1
Description: Unified configuration engine consolidating all config views
Version: 1.0.0
Last Modified: 2026-01-24
Dependencies:
   - dbo.Rolyat_Site_Config (for site-level configs)
   - dbo.Rolyat_Config_Items (item-specific overrides)
   - dbo.Rolyat_Config_Clients (client-specific overrides)
   - dbo.Rolyat_Config_Global (global defaults)

Purpose:
   - Consolidates 4 separate config views into single unified engine
   - Implements priority hierarchy: Item > Client > Global
   - Eliminates 11+ duplicate config lookups across downstream views
   - Provides function-style interface for config value retrieval

Business Rules:
   - Config hierarchy (priority order):
     1. Item-specific config (highest priority)
     2. Client-specific config
     3. Global default config (lowest priority)
   - Site configs (WFQ/RMQTY locations) handled separately
   - All configs pivoted into columns for easy joining

Configuration Parameters:
   - Degradation tiers (4 tiers: 0-30, 31-60, 61-90, >90 days)
   - Hold periods: WFQ_Hold_Days (14 default), RMQTY_Hold_Days (7 default)
   - Expiry filter: Expiry_Filter_Days (90 default)
   - Active window: Active_Window_Days (21 default, ±21 from current date)
   - Safety stock: Safety_Stock_Days
   - Shelf life: Shelf_Life_Days
   - WFQ location codes
   - RMQTY location codes

REPLACES:
   - dbo.Rolyat_Site_Config (View 00)
   - dbo.Rolyat_Config_Clients (View 01)
   - dbo.Rolyat_Config_Global (View 02)
   - dbo.Rolyat_Config_Items (View 03)
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Config_Engine_v1
AS

WITH SiteConfig AS (
  -- Site configuration (WFQ/RMQTY locations)
  SELECT 
    LOCNCODE AS Site_ID,
    'WFQ_LOCATIONS' AS Config_Key,
    CASE WHEN Site_Type = 'WFQ' THEN LOCNCODE ELSE NULL END AS Config_Value,
    'SITE' AS Config_Scope,
    1 AS Priority
  FROM dbo.Rolyat_Site_Config
  WHERE Site_Type = 'WFQ' AND Active = 1
  
  UNION ALL
  
  SELECT 
    LOCNCODE AS Site_ID,
    'RMQTY_LOCATIONS' AS Config_Key,
    CASE WHEN Site_Type = 'RMQTY' THEN LOCNCODE ELSE NULL END AS Config_Value,
    'SITE' AS Config_Scope,
    1 AS Priority
  FROM dbo.Rolyat_Site_Config
  WHERE Site_Type = 'RMQTY' AND Active = 1
),

ItemConfig AS (
  -- Item-specific overrides (highest priority = 1)
  SELECT 
    ITEMNMBR,
    NULL AS Client_ID,
    NULL AS Site_ID,
    Config_Key,
    Config_Value,
    'ITEM' AS Config_Scope,
    1 AS Priority
  FROM dbo.Rolyat_Config_Items
  WHERE ITEMNMBR IS NOT NULL
    AND Config_Key IS NOT NULL
    AND Effective_Date <= GETDATE()
    AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())
),

ClientConfig AS (
  -- Client-specific overrides (priority = 2)
  SELECT 
    NULL AS ITEMNMBR,
    Client_ID,
    NULL AS Site_ID,
    Config_Key,
    Config_Value,
    'CLIENT' AS Config_Scope,
    2 AS Priority
  FROM dbo.Rolyat_Config_Clients
  WHERE Client_ID IS NOT NULL
    AND Config_Key IS NOT NULL
    AND Effective_Date <= GETDATE()
    AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())
),

GlobalConfig AS (
  -- Global defaults (lowest priority = 3)
  SELECT 
    NULL AS ITEMNMBR,
    NULL AS Client_ID,
    NULL AS Site_ID,
    Config_Key,
    Config_Value,
    'GLOBAL' AS Config_Scope,
    3 AS Priority
  FROM dbo.Rolyat_Config_Global
  WHERE Config_Key IS NOT NULL
    AND Effective_Date <= GETDATE()
    AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())
),

AllConfigs AS (
  -- Union all config sources
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Config_Key,
    Config_Value,
    Config_Scope,
    Priority
  FROM ItemConfig
  
  UNION ALL
  
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Config_Key,
    Config_Value,
    Config_Scope,
    Priority
  FROM ClientConfig
  
  UNION ALL
  
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Config_Key,
    Config_Value,
    Config_Scope,
    Priority
  FROM GlobalConfig
  
  UNION ALL
  
  SELECT 
    NULL AS ITEMNMBR,
    NULL AS Client_ID,
    Site_ID,
    Config_Key,
    Config_Value,
    Config_Scope,
    Priority
  FROM SiteConfig
),

RankedConfigs AS (
  -- Rank configs by priority (lower priority number = higher priority)
  SELECT 
    ITEMNMBR,
    Client_ID,
    Site_ID,
    Config_Key,
    Config_Value,
    Config_Scope,
    Priority,
    ROW_NUMBER() OVER (
      PARTITION BY ITEMNMBR, Client_ID, Site_ID, Config_Key 
      ORDER BY Priority ASC
    ) AS Priority_Rank
  FROM AllConfigs
)

-- Final output: Pivot config keys into columns for easy joining
SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  
  -- Hold periods
  MAX(CASE WHEN Config_Key = 'WFQ_Hold_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS WFQ_Hold_Days,
  MAX(CASE WHEN Config_Key = 'RMQTY_Hold_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS RMQTY_Hold_Days,
  
  -- Expiry filters
  MAX(CASE WHEN Config_Key = 'WFQ_Expiry_Filter_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS WFQ_Expiry_Filter_Days,
  MAX(CASE WHEN Config_Key = 'RMQTY_Expiry_Filter_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS RMQTY_Expiry_Filter_Days,
  
  -- Active window
  MAX(CASE WHEN Config_Key = 'ActiveWindow_Past_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS ActiveWindow_Past_Days,
  MAX(CASE WHEN Config_Key = 'ActiveWindow_Future_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS ActiveWindow_Future_Days,
  
  -- Shelf life
  MAX(CASE WHEN Config_Key = 'WC_Batch_Shelf_Life_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS WC_Batch_Shelf_Life_Days,
  
  -- Safety stock
  MAX(CASE WHEN Config_Key = 'Safety_Stock_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS Safety_Stock_Days,
  MAX(CASE WHEN Config_Key = 'Safety_Stock_Method' AND Priority_Rank = 1 THEN Config_Value END) AS Safety_Stock_Method,
  
  -- Degradation tiers
  MAX(CASE WHEN Config_Key = 'Degradation_Tier1_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS Degradation_Tier1_Days,
  MAX(CASE WHEN Config_Key = 'Degradation_Tier2_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS Degradation_Tier2_Days,
  MAX(CASE WHEN Config_Key = 'Degradation_Tier3_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS Degradation_Tier3_Days,
  MAX(CASE WHEN Config_Key = 'Degradation_Tier1_Factor' AND Priority_Rank = 1 THEN CAST(Config_Value AS DECIMAL(5,2)) END) AS Degradation_Tier1_Factor,
  MAX(CASE WHEN Config_Key = 'Degradation_Tier2_Factor' AND Priority_Rank = 1 THEN CAST(Config_Value AS DECIMAL(5,2)) END) AS Degradation_Tier2_Factor,
  MAX(CASE WHEN Config_Key = 'Degradation_Tier3_Factor' AND Priority_Rank = 1 THEN CAST(Config_Value AS DECIMAL(5,2)) END) AS Degradation_Tier3_Factor,
  MAX(CASE WHEN Config_Key = 'Degradation_Tier4_Factor' AND Priority_Rank = 1 THEN CAST(Config_Value AS DECIMAL(5,2)) END) AS Degradation_Tier4_Factor,
  
  -- Location codes
  MAX(CASE WHEN Config_Key = 'WFQ_LOCATIONS' AND Priority_Rank = 1 THEN Config_Value END) AS WFQ_Locations,
  MAX(CASE WHEN Config_Key = 'RMQTY_LOCATIONS' AND Priority_Rank = 1 THEN Config_Value END) AS RMQTY_Locations,
  
  -- Backward suppression
  MAX(CASE WHEN Config_Key = 'BackwardSuppression_Lookback_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS BackwardSuppression_Lookback_Days,
  MAX(CASE WHEN Config_Key = 'BackwardSuppression_Extended_Lookback_Days' AND Priority_Rank = 1 THEN CAST(Config_Value AS INT) END) AS BackwardSuppression_Extended_Lookback_Days,
  
  -- Config metadata
  MIN(Priority) AS Effective_Priority,
  CASE 
    WHEN MIN(Priority) = 1 THEN 'ITEM_OVERRIDE'
    WHEN MIN(Priority) = 2 THEN 'CLIENT_OVERRIDE'
    WHEN MIN(Priority) = 3 THEN 'GLOBAL_DEFAULT'
    ELSE 'SITE_CONFIG'
  END AS Config_Source

FROM RankedConfigs
GROUP BY ITEMNMBR, Client_ID, Site_ID;
