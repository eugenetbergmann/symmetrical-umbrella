/*
===============================================================================
View: dbo.Rolyat_WC_Inventory
Description: Work Center (WC) batch inventory derived from bin quantities
Version: 2.2.0
Last Modified: 2026-01-22
Dependencies:
  - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
  - dbo.EXT_BINTYPE
  - dbo.Rolyat_Config_Items
  - dbo.Rolyat_Config_Global

Purpose:
  - Extracts WC batch inventory from bin quantities
  - Calculates batch expiry based on configurable shelf life or explicit expiry date
  - Provides age calculation for degradation factor application
  - Includes bin location and type information

Business Rules:
  - Only includes records with SITE LIKE 'WC[_-]%'
  - Only includes records with QTY_Available > 0
  - Only includes records with valid LOT_Number
  - Batch expiry = EXPNDATE if available, else DATERECD + Configurable Shelf Life Days
  - Client_ID extracted from SITE before first '-' or '_'

Implementation Notes:
  - Sources directly from dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
  - Joins with dbo.EXT_BINTYPE for bin type information
  - Uses CONCAT for string concatenation
  - Handles NULL bin types with ISNULL
===============================================================================
*/

CREATE OR ALTER VIEW dbo.Rolyat_WC_Inventory
AS

WITH WC_Batches AS (
    SELECT
        inv.Item_Number AS ITEMNMBR,
        
        -- FIXED: Simplified Client_ID extraction
        LEFT(inv.SITE, CASE 
            WHEN CHARINDEX('-', inv.SITE) > 0 THEN CHARINDEX('-', inv.SITE) - 1
            ELSE LEN(inv.SITE)
        END) AS Client_ID,
        
        inv.SITE AS Site_ID,
        
        -- FIXED: Use CONCAT instead of + for string concatenation
        CONCAT(inv.LOT_Number, '_', inv.Bin) AS WC_Batch_ID,
        
        inv.QTY_Available AS Available_Qty,
        inv.DATERECD AS Batch_Receipt_Date,
        
        COALESCE(
            inv.EXPNDATE,
            DATEADD(DAY,
                CAST(COALESCE(
                    (SELECT Config_Value 
                     FROM dbo.Rolyat_Config_Items ci 
                     WHERE ci.ITEMNMBR = inv.Item_Number 
                       AND ci.Config_Key = 'WC_Batch_Shelf_Life_Days' 
                       AND ci.Effective_Date <= GETDATE() 
                       AND (ci.Expiry_Date IS NULL OR ci.Expiry_Date > GETDATE())),
                    (SELECT Config_Value 
                     FROM dbo.Rolyat_Config_Global cg 
                     WHERE cg.Config_Key = 'WC_Batch_Shelf_Life_Days' 
                       AND cg.Effective_Date <= GETDATE() 
                       AND (cg.Expiry_Date IS NULL OR cg.Expiry_Date > GETDATE())),
                    365
                ) AS INT),
                inv.DATERECD
            )
        ) AS Batch_Expiry_Date,
        
        DATEDIFF(DAY, inv.DATERECD, GETDATE()) AS Batch_Age_Days,
        'WC_BATCH' AS Row_Type,
        inv.Bin AS Bin_Location,
        
        -- FIXED: Handle potential NULL from TRIM
        ISNULL(TRIM(bt.[Bin Type ID]), 'UNKNOWN') AS Bin_Type,

        -- Degradation placeholders (not implemented yet)
        0 AS Degraded_Qty,
        inv.QTY_Available AS Usable_Qty

    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE inv
    LEFT OUTER JOIN dbo.EXT_BINTYPE bt 
        ON inv.Bin = bt.Bin 
       AND inv.SITE = bt.[Location Code]
    WHERE inv.SITE LIKE 'WC[_-]%'
      AND inv.QTY_Available > 0
      AND inv.LOT_Number IS NOT NULL
      AND inv.LOT_Number <> ''
)
SELECT
    ITEMNMBR,
    Client_ID,
    Site_ID,
    WC_Batch_ID,
    Available_Qty,
    Batch_Receipt_Date,
    Batch_Expiry_Date,
    Batch_Age_Days,
    Row_Type,
    Bin_Location,
    Bin_Type,
    Degraded_Qty,
    Usable_Qty,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Batch_Expiry_Date ASC, Batch_Receipt_Date ASC
    ) AS SortPriority
FROM WC_Batches

-- ============================================================
-- VALIDATION QUERIES (run after deploy):
-- ============================================================
-- Test 1: Row count & WC sites only
SELECT COUNT(*) AS Total_Rows, COUNT(DISTINCT Site_ID) AS Unique_WC_Sites FROM dbo.Rolyat_WC_Inventory;
-- Test 2: No bleed to other prefixes
SELECT COUNT(*) FROM dbo.Rolyat_WC_Inventory WHERE Site_ID NOT LIKE 'WC[_-]%';
-- Test 3: FEFO order check
SELECT TOP 50 * FROM dbo.Rolyat_WC_Inventory ORDER BY SortPriority, Batch_Expiry_Date;
