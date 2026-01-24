/*
===============================================================================
View: dbo.ETB2_Inventory_Unified_v1
Description: Unified inventory view consolidating WC, WFQ, and RMQTY batches
Version: 1.0.0
Last Modified: 2026-01-24
Dependencies:
   - dbo.Prosenthal_INV_BIN_QTY (WC batch data)
   - dbo.IV00300 (inventory lot master)
   - dbo.IV00101 (item master)
   - dbo.Rolyat_Site_Config (site configuration)
   - dbo.ETB2_Config_Engine_v1 (configuration engine)

Purpose:
   - Consolidates WC batch inventory, WFQ batches, and RMQTY batches
   - Calculates batch expiry, age, and release eligibility
   - Provides unified interface for inventory allocation
   - Eliminates 5+ JOIN duplications across downstream views

Business Rules:
   - WC batches: Physical bin locations, expiry from EXPNDATE or DATERECD + Shelf_Life
   - WFQ batches: Hold period (14 days default), release eligibility based on DATERECD
   - RMQTY batches: Hold period (7 days default), different release logic
   - All batches sorted by FEFO (First Expiry First Out)
   - Inventory_Type distinguishes batch source for allocation logic

REPLACES:
   - dbo.Rolyat_WC_Inventory (View 05)
   - dbo.Rolyat_WFQ_5 (View 06) - partially (WFQ and RMQTY portions)

USAGE IN DOWNSTREAM VIEWS:
   - Replace Rolyat_WC_Inventory → ETB2_Inventory_Unified_v1 WHERE Inventory_Type = 'WC_BATCH'
   - Replace Rolyat_WFQ_5 → ETB2_Inventory_Unified_v1 WHERE Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH')
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Inventory_Unified_v1
AS

WITH WC_Batches AS (
  -- WC inventory from bin quantities (View 05 logic)
  SELECT 
    BQ.ITEMNMBR,
    BQ.Client_ID,
    BQ.LOCNCODE AS Site_ID,
    BQ.BIN AS Bin_Location,
    BQ.Bin_Type,
    BQ.QTY_ON_HAND,
    'WC_BATCH' AS Inventory_Type,
    
    -- Expiry date logic (View 05 has this)
    COALESCE(
      CAST(BQ.EXPNDATE AS date),  -- Explicit expiry if available
      DATEADD(DAY, ISNULL(CFG.Shelf_Life_Days, 180), CAST(R.DATERECD AS date))  -- Receipt + shelf life
    ) AS Expiry_Date,
    
    CAST(R.DATERECD AS date) AS Receipt_Date,
    
    DATEDIFF(DAY, CAST(R.DATERECD AS date), CAST(GETDATE() AS date)) AS Age_Days,
    
    -- No hold period for WC
    CAST(GETDATE() AS date) AS Projected_Release_Date,
    0 AS Days_Until_Release,
    1 AS Is_Eligible_For_Release,  -- WC always eligible
    
    BQ.UOFM AS UOM,
    1 AS SortPriority,  -- WC first in allocation
    
    -- Batch ID for uniqueness
    CONCAT('WC-', BQ.LOCNCODE, '-', BQ.BIN, '-', BQ.ITEMNMBR, '-', CONVERT(VARCHAR(10), R.DATERECD, 112)) AS Batch_ID
    
  FROM Prosenthal_INV_BIN_QTY BQ WITH (NOLOCK)
  INNER JOIN IV00300 R WITH (NOLOCK)
    ON BQ.ITEMNMBR = R.ITEMNMBR
   AND BQ.LOCNCODE = R.LOCNCODE
   AND BQ.RCPTNMBR = R.RCPTNMBR  -- Match to receipt
  LEFT JOIN ETB2_Config_Engine_v1 CFG
    ON BQ.ITEMNMBR = CFG.ITEMNMBR
  WHERE BQ.QTY_ON_HAND > 0
),

WFQ_Batches AS (
  -- WFQ inventory (View 06 WFQ portion)
  SELECT 
    I.ITEMNMBR,
    NULL AS Client_ID,  -- Not tracked for WFQ
    I.LOCNCODE AS Site_ID,
    NULL AS Bin_Location,  -- WFQ not in bins
    NULL AS Bin_Type,
    I.ATYALLOC AS QTY_ON_HAND,
    'WFQ_BATCH' AS Inventory_Type,
    
    -- No expiry for WFQ (or derive from receipt if needed)
    NULL AS Expiry_Date,
    
    CAST(R.DATERECD AS date) AS Receipt_Date,
    
    DATEDIFF(DAY, CAST(R.DATERECD AS date), CAST(GETDATE() AS date)) AS Age_Days,
    
    -- WFQ hold period (14 days default from config)
    DATEADD(DAY, ISNULL(CFG.WFQ_Hold_Days, 14), CAST(R.DATERECD AS date)) AS Projected_Release_Date,
    ISNULL(CFG.WFQ_Hold_Days, 14) - DATEDIFF(DAY, CAST(R.DATERECD AS date), CAST(GETDATE() AS date)) AS Days_Until_Release,
    CASE 
      WHEN DATEDIFF(DAY, CAST(R.DATERECD AS date), CAST(GETDATE() AS date)) >= ISNULL(CFG.WFQ_Hold_Days, 14)
      THEN 1 ELSE 0 
    END AS Is_Eligible_For_Release,
    
    I.UOMSCHDL AS UOM,
    2 AS SortPriority,  -- WFQ second in allocation
    
    CONCAT('WFQ-', I.LOCNCODE, '-', I.ITEMNMBR, '-', CONVERT(VARCHAR(10), R.DATERECD, 112)) AS Batch_ID
    
  FROM IV00102 I WITH (NOLOCK)
  LEFT JOIN IV00300 R WITH (NOLOCK)
    ON I.ITEMNMBR = R.ITEMNMBR
   AND I.LOCNCODE = R.LOCNCODE
  LEFT JOIN ETB2_Config_Engine_v1 CFG
    ON I.ITEMNMBR = CFG.ITEMNMBR
  WHERE I.ATYALLOC > 0
    AND I.LOCNCODE IN (SELECT Site_ID FROM ETB2_Config_Engine_v1 WHERE WFQ_Locations IS NOT NULL)  -- WFQ sites only
),

RMQTY_Batches AS (
  -- RMQTY inventory (View 06 RMQTY portion)
  SELECT 
    I.ITEMNMBR,
    NULL AS Client_ID,
    I.LOCNCODE AS Site_ID,
    NULL AS Bin_Location,
    NULL AS Bin_Type,
    I.QTY_RM_I AS QTY_ON_HAND,
    'RMQTY_BATCH' AS Inventory_Type,
    
    NULL AS Expiry_Date,
    
    CAST(R.DATERECD AS date) AS Receipt_Date,
    
    DATEDIFF(DAY, CAST(R.DATERECD AS date), CAST(GETDATE() AS date)) AS Age_Days,
    
    -- RMQTY hold period (7 days default)
    DATEADD(DAY, ISNULL(CFG.RMQTY_Hold_Days, 7), CAST(R.DATERECD AS date)) AS Projected_Release_Date,
    ISNULL(CFG.RMQTY_Hold_Days, 7) - DATEDIFF(DAY, CAST(R.DATERECD AS date), CAST(GETDATE() AS date)) AS Days_Until_Release,
    CASE 
      WHEN DATEDIFF(DAY, CAST(R.DATERECD AS date), CAST(GETDATE() AS date)) >= ISNULL(CFG.RMQTY_Hold_Days, 7)
      THEN 1 ELSE 0 
    END AS Is_Eligible_For_Release,
    
    I.UOMSCHDL AS UOM,
    3 AS SortPriority,  -- RMQTY third in allocation
    
    CONCAT('RM-', I.LOCNCODE, '-', I.ITEMNMBR, '-', CONVERT(VARCHAR(10), R.DATERECD, 112)) AS Batch_ID
    
  FROM IV00102 I WITH (NOLOCK)
  LEFT JOIN IV00300 R WITH (NOLOCK)
    ON I.ITEMNMBR = R.ITEMNMBR
   AND I.LOCNCODE = R.LOCNCODE
  LEFT JOIN ETB2_Config_Engine_v1 CFG
    ON I.ITEMNMBR = CFG.ITEMNMBR
  WHERE I.QTY_RM_I > 0
    AND I.LOCNCODE IN (SELECT Site_ID FROM ETB2_Config_Engine_v1 WHERE RMQTY_Locations IS NOT NULL)
)

-- Union all inventory types
SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Batch_ID,
  QTY_ON_HAND,
  Inventory_Type,
  Receipt_Date,
  Expiry_Date,
  Age_Days,
  Projected_Release_Date,
  Days_Until_Release,
  Is_Eligible_For_Release,
  Bin_Location,
  Bin_Type,
  UOM,
  SortPriority
FROM WC_Batches

UNION ALL

SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Batch_ID,
  QTY_ON_HAND,
  Inventory_Type,
  Receipt_Date,
  Expiry_Date,
  Age_Days,
  Projected_Release_Date,
  Days_Until_Release,
  Is_Eligible_For_Release,
  Bin_Location,
  Bin_Type,
  UOM,
  SortPriority
FROM WFQ_Batches

UNION ALL

SELECT 
  ITEMNMBR,
  Client_ID,
  Site_ID,
  Batch_ID,
  QTY_ON_HAND,
  Inventory_Type,
  Receipt_Date,
  Expiry_Date,
  Age_Days,
  Projected_Release_Date,
  Days_Until_Release,
  Is_Eligible_For_Release,
  Bin_Location,
  Bin_Type,
  UOM,
  SortPriority
FROM RMQTY_Batches;
