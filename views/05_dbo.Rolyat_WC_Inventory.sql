/*
==============================================================================
View: dbo.Rolyat_WC_Inventory
Description: Work Center (WC) batch inventory from INV_BIN_QTY
Version: 1.0.0
Last Modified: 2026-01-22
Dependencies:
  - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
  - dbo.EXT_BINTYPE
  - dbo.Rolyat_Config_Items
  - dbo.Rolyat_Config_Global

Purpose:
  - Extracts WC batch inventory from bin quantity data
  - Calculates batch expiry based on configurable shelf life
  - Provides age calculation for degradation factor application

Business Rules:
  - Only includes WC sites (SITE LIKE 'WC[_-]%')
  - Only includes records with available quantity > 0
  - Only includes records with valid LOT_Number
  - Batch expiry = Receipt Date + Configurable Shelf Life Days or EXPNDATE

Implementation Notes:
  - Sources from Prosenthal_INV_BIN_QTY_wQTYTYPE with WC site filter
  - Uses LEFT OUTER JOIN to EXT_BINTYPE for bin type information
==============================================================================
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
        ISNULL(TRIM(bt.[Bin Type ID]), 'UNKNOWN') AS Bin_Type

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
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Batch_Expiry_Date ASC, Batch_Receipt_Date ASC
    ) AS SortPriority
FROM WC_Batches
