/*
================================================================================
View: dbo.Rolyat_Batch_Expiry_Risk_Dashboard
Description: Track batch expiry risks with clear timeline (10 columns max)
Version: 1.0.0
Last Modified: 2026-01-24
Dependencies: 
  - dbo.Rolyat_WC_Inventory
  - dbo.Rolyat_WFQ_5

Purpose:
  - Provides batch-level expiry risk visibility across inventory locations
  - Tells the story: "Here's what batches are expiring when and what to do about them"
  - Optimized for single-screen viewing with 10 columns max
  - No CTEs - direct query for performance
  - Combines WC (Work Center), WFQ (Quality Hold), and RMQTY (Rework) batches

Business Rules:
  - Expiry risk tiers based on days until expiry
  - Recommended disposition varies by hold location type
  - WFQ batches held > 14 days can be released after hold
  - RMQTY batches held > 7 days can be released after hold
  - Expired batches flagged for immediate action
================================================================================
*/

SELECT 
    -- ============================================================
    -- Batch Identification (3 columns)
    -- ============================================================
    'WC_BATCH' AS Batch_Type,
    ITEMNMBR,
    Batch_ID,
    
    -- ============================================================
    -- Location & Quantity (2 columns)
    -- ============================================================
    Client_ID,
    QTY_ON_HAND AS Batch_Qty,
    
    -- ============================================================
    -- Expiry Timeline (2 columns)
    -- ============================================================
    Expiry_Date,
    DATEDIFF(day, GETDATE(), Expiry_Date) AS Days_Until_Expiry,
    
    -- ============================================================
    -- Risk Assessment & Action (3 columns)
    -- ============================================================
    CASE 
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) < 0 THEN 'EXPIRED'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 30 THEN 'CRITICAL'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 60 THEN 'HIGH'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 90 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Expiry_Risk_Tier,
    'USE_FIRST' AS Recommended_Disposition,
    Site_ID

FROM dbo.Rolyat_WC_Inventory

UNION ALL

SELECT 
    -- ============================================================
    -- Batch Identification (3 columns)
    -- ============================================================
    'WFQ_BATCH' AS Batch_Type,
    ITEMNMBR,
    Batch_ID,
    
    -- ============================================================
    -- Location & Quantity (2 columns)
    -- ============================================================
    Client_ID,
    QTY_ON_HAND AS Batch_Qty,
    
    -- ============================================================
    -- Expiry Timeline (2 columns)
    -- ============================================================
    Expiry_Date,
    DATEDIFF(day, GETDATE(), Expiry_Date) AS Days_Until_Expiry,
    
    -- ============================================================
    -- Risk Assessment & Action (3 columns)
    -- ============================================================
    CASE 
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) < 0 THEN 'EXPIRED'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 30 THEN 'CRITICAL'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 60 THEN 'HIGH'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 90 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Expiry_Risk_Tier,
    CASE 
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) > 14 THEN 'RELEASE_AFTER_HOLD'
        ELSE 'HOLD_IN_WFQ'
    END AS Recommended_Disposition,
    Site_ID

FROM dbo.Rolyat_WFQ_5
WHERE Hold_Location_Type = 'WFQ'

UNION ALL

SELECT 
    -- ============================================================
    -- Batch Identification (3 columns)
    -- ============================================================
    'RMQTY_BATCH' AS Batch_Type,
    ITEMNMBR,
    Batch_ID,
    
    -- ============================================================
    -- Location & Quantity (2 columns)
    -- ============================================================
    Client_ID,
    QTY_ON_HAND AS Batch_Qty,
    
    -- ============================================================
    -- Expiry Timeline (2 columns)
    -- ============================================================
    Expiry_Date,
    DATEDIFF(day, GETDATE(), Expiry_Date) AS Days_Until_Expiry,
    
    -- ============================================================
    -- Risk Assessment & Action (3 columns)
    -- ============================================================
    CASE 
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) < 0 THEN 'EXPIRED'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 30 THEN 'CRITICAL'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 60 THEN 'HIGH'
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) <= 90 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Expiry_Risk_Tier,
    CASE 
        WHEN DATEDIFF(day, GETDATE(), Expiry_Date) > 7 THEN 'RELEASE_AFTER_HOLD'
        ELSE 'HOLD_IN_RMQTY'
    END AS Recommended_Disposition,
    Site_ID

FROM dbo.Rolyat_WFQ_5
WHERE Hold_Location_Type = 'RMQTY'
