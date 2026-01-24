/*
================================================================================
View: dbo.Rolyat_Batch_Expiry_Risk_Dashboard
Description: Track batch expiry risks with clear timeline (10 columns max)
Version: 1.1.0
Last Modified: 2026-01-24
Dependencies:
  - dbo.ETB2_Inventory_Unified_v1 (replaces Rolyat_WC_Inventory and Rolyat_WFQ_5)

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
    Inventory_Type AS Batch_Type,
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
        WHEN Inventory_Type = 'WC_BATCH' THEN 'USE_FIRST'
        WHEN Inventory_Type = 'WFQ_BATCH' AND DATEDIFF(day, GETDATE(), Expiry_Date) > 14 THEN 'RELEASE_AFTER_HOLD'
        WHEN Inventory_Type = 'WFQ_BATCH' THEN 'HOLD_IN_WFQ'
        WHEN Inventory_Type = 'RMQTY_BATCH' AND DATEDIFF(day, GETDATE(), Expiry_Date) > 7 THEN 'RELEASE_AFTER_HOLD'
        WHEN Inventory_Type = 'RMQTY_BATCH' THEN 'HOLD_IN_RMQTY'
        ELSE 'UNKNOWN'
    END AS Recommended_Disposition,
    Site_ID

FROM dbo.ETB2_Inventory_Unified_v1
WHERE Expiry_Date IS NOT NULL
