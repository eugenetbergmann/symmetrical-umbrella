/*
===============================================================================
View: dbo.ETB2_Inventory_Unified_v1
Description: Unified inventory view consolidating WC, WFQ, and RMQTY batches
Version: 1.0.0
Last Modified: 2026-01-24
Dependencies:
   - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (WC batch data)
   - dbo.EXT_BINTYPE (bin type information)
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
  -- WC inventory from bin quantities
  SELECT 
    inv.Item_Number AS ITEMNMBR,
    LEFT(inv.SITE, CASE 
      WHEN CHARINDEX('-', inv.SITE) > 0 THEN CHARINDEX('-', inv.SITE) - 1
      ELSE LEN(inv.SITE)
    END) AS Client_ID,
    inv.SITE AS Site_ID,
    CONCAT(inv.LOT_Number, '_', inv.Bin) AS Batch_ID,
    inv.QTY_Available AS QTY_ON_HAND,
    'WC_BATCH' AS Inventory_Type,
    CAST(inv.DATERECD AS DATE) AS Receipt_Date,
    COALESCE(
      CAST(inv.EXPNDATE AS DATE),
      DATEADD(DAY, ISNULL(CFG.WC_Batch_Shelf_Life_Days, 180), CAST(inv.DATERECD AS DATE))
    ) AS Expiry_Date,
    DATEDIFF(DAY, CAST(inv.DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Age_Days,
    CAST(GETDATE() AS DATE) AS Projected_Release_Date,
    0 AS Days_Until_Release,
    1 AS Is_Eligible_For_Release,
    inv.Bin AS Bin_Location,
    ISNULL(TRIM(bt.[Bin Type ID]), 'UNKNOWN') AS Bin_Type,
    TRIM(inv.UOFM) AS UOM,
    1 AS SortPriority,
    ROW_NUMBER() OVER (
      PARTITION BY inv.Item_Number
      ORDER BY COALESCE(CAST(inv.EXPNDATE AS DATE), DATEADD(DAY, ISNULL(CFG.WC_Batch_Shelf_Life_Days, 180), CAST(inv.DATERECD AS DATE))) ASC, 
               CAST(inv.DATERECD AS DATE) ASC
    ) AS FEFO_Rank
  FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE inv
  LEFT OUTER JOIN dbo.EXT_BINTYPE bt 
    ON inv.Bin = bt.Bin 
   AND inv.SITE = bt.[Location Code]
  LEFT JOIN dbo.ETB2_Config_Engine_v1 CFG
    ON inv.Item_Number = CFG.ITEMNMBR
  WHERE inv.SITE LIKE 'WC[_-]%'
    AND inv.QTY_Available > 0
    AND inv.LOT_Number IS NOT NULL
    AND inv.LOT_Number <> ''
),

WFQ_Batches AS (
  -- WFQ inventory (quarantine)
  SELECT 
    TRIM(inv.ITEMNMBR) AS ITEMNMBR,
    NULL AS Client_ID,
    TRIM(inv.LOCNCODE) AS Site_ID,
    CAST(inv.RCTSEQNM AS VARCHAR(50)) AS Batch_ID,
    SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND,
    'WFQ_BATCH' AS Inventory_Type,
    MAX(CAST(inv.DATERECD AS DATE)) AS Receipt_Date,
    MAX(CAST(inv.EXPNDATE AS DATE)) AS Expiry_Date,
    DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
    DATEADD(DAY, ISNULL(CFG.WFQ_Hold_Days, 14), MAX(CAST(inv.DATERECD AS DATE))) AS Projected_Release_Date,
    ISNULL(CFG.WFQ_Hold_Days, 14) - DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Days_Until_Release,
    CASE 
      WHEN DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), CAST(GETDATE() AS DATE)) >= ISNULL(CFG.WFQ_Hold_Days, 14)
      THEN 1 ELSE 0 
    END AS Is_Eligible_For_Release,
    NULL AS Bin_Location,
    NULL AS Bin_Type,
    TRIM(itm.UOMSCHDL) AS UOM,
    2 AS SortPriority,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(inv.ITEMNMBR)
      ORDER BY MAX(CAST(inv.DATERECD AS DATE)) ASC
    ) AS FEFO_Rank
  FROM dbo.IV00300 inv
  LEFT OUTER JOIN dbo.IV00101 itm
    ON inv.ITEMNMBR = itm.ITEMNMBR
  LEFT JOIN dbo.ETB2_Config_Engine_v1 CFG
    ON TRIM(inv.ITEMNMBR) = CFG.ITEMNMBR
  WHERE (inv.QTYRECVD - inv.QTYSOLD <> 0)
    AND TRIM(inv.LOCNCODE) IN (
      SELECT LOCNCODE
      FROM dbo.Rolyat_Site_Config
      WHERE Site_Type = 'WFQ' AND Active = 1
    )
    AND (inv.EXPNDATE IS NULL
      OR inv.EXPNDATE > DATEADD(DAY, ISNULL(CFG.WFQ_Expiry_Filter_Days, 90), CAST(GETDATE() AS DATE))
    )
  GROUP BY
    TRIM(inv.ITEMNMBR),
    TRIM(inv.LOCNCODE),
    CAST(inv.RCTSEQNM AS VARCHAR(50)),
    TRIM(itm.UOMSCHDL),
    CFG.WFQ_Hold_Days,
    CFG.WFQ_Expiry_Filter_Days
  HAVING (SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0)
),

RMQTY_Batches AS (
  -- RMQTY inventory (restricted material)
  SELECT 
    TRIM(inv.ITEMNMBR) AS ITEMNMBR,
    NULL AS Client_ID,
    TRIM(inv.LOCNCODE) AS Site_ID,
    CAST(inv.RCTSEQNM AS VARCHAR(50)) AS Batch_ID,
    SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND,
    'RMQTY_BATCH' AS Inventory_Type,
    MAX(CAST(inv.DATERECD AS DATE)) AS Receipt_Date,
    MAX(CAST(inv.EXPNDATE AS DATE)) AS Expiry_Date,
    DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
    DATEADD(DAY, ISNULL(CFG.RMQTY_Hold_Days, 7), MAX(CAST(inv.DATERECD AS DATE))) AS Projected_Release_Date,
    ISNULL(CFG.RMQTY_Hold_Days, 7) - DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Days_Until_Release,
    CASE 
      WHEN DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), CAST(GETDATE() AS DATE)) >= ISNULL(CFG.RMQTY_Hold_Days, 7)
      THEN 1 ELSE 0 
    END AS Is_Eligible_For_Release,
    NULL AS Bin_Location,
    NULL AS Bin_Type,
    TRIM(itm.UOMSCHDL) AS UOM,
    3 AS SortPriority,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(inv.ITEMNMBR)
      ORDER BY MAX(CAST(inv.DATERECD AS DATE)) ASC
    ) AS FEFO_Rank
  FROM dbo.IV00300 inv
  LEFT OUTER JOIN dbo.IV00101 itm
    ON inv.ITEMNMBR = itm.ITEMNMBR
  LEFT JOIN dbo.ETB2_Config_Engine_v1 CFG
    ON TRIM(inv.ITEMNMBR) = CFG.ITEMNMBR
  WHERE (inv.QTYRECVD - inv.QTYSOLD <> 0)
    AND TRIM(inv.LOCNCODE) IN (
      SELECT LOCNCODE
      FROM dbo.Rolyat_Site_Config
      WHERE Site_Type = 'RMQTY' AND Active = 1
    )
    AND (inv.EXPNDATE IS NULL
      OR inv.EXPNDATE > DATEADD(DAY, ISNULL(CFG.RMQTY_Expiry_Filter_Days, 90), CAST(GETDATE() AS DATE))
    )
  GROUP BY
    TRIM(inv.ITEMNMBR),
    TRIM(inv.LOCNCODE),
    CAST(inv.RCTSEQNM AS VARCHAR(50)),
    TRIM(itm.UOMSCHDL),
    CFG.RMQTY_Hold_Days,
    CFG.RMQTY_Expiry_Filter_Days
  HAVING (SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0)
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
  SortPriority,
  FEFO_Rank
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
  SortPriority,
  FEFO_Rank
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
  SortPriority,
  FEFO_Rank
FROM RMQTY_Batches;
