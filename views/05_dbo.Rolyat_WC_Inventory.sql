/*
================================================================================
View: dbo.Rolyat_WC_Inventory
Description: Work Center (WC) batch inventory derived from demand data
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.Rolyat_Cleaned_Base_Demand_1
  - dbo.fn_GetConfig (Configuration function)

Purpose:
  - Extracts WC batch inventory from partially issued manufacturing orders
  - Calculates batch expiry based on configurable shelf life
  - Provides age calculation for degradation factor application

Business Rules:
  - Only includes records with valid WCID_From_MO
  - Only includes records with remaining quantity > 0
  - Only includes records where Has_Issued = 'YES' (partial issuance)
  - Batch expiry = Issue Date + Configurable Shelf Life Days

Implementation Notes:
  - Option A (current): Sources from ETB_PAB_AUTO via WCID_From_MO/Remaining
  - Option B (alternative): Sources from IV00300 with WC site filter
  - Choose implementation based on your WC tracking method
================================================================================
*/

CREATE OR ALTER VIEW dbo.Rolyat_WC_Inventory
AS
SELECT
    -- Item identifier
    ITEMNMBR,
    
    -- Client/Site identifiers
    Construct AS Client_ID,
    SITE AS Site_ID,
    
    -- Batch identifier
    WCID_From_MO AS WC_Batch_ID,
    
    -- Available quantity
    MRP_Remaining_Qty AS Available_Qty,
    
    -- Receipt date (issue date)
    MRP_IssueDate AS Batch_Receipt_Date,

    -- ============================================================
    -- Batch Expiry Calculation
    -- Issue Date + Configurable Shelf Life Days
    -- ============================================================
    DATEADD(DAY,
        CAST(COALESCE(
            (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = wc.ITEMNMBR AND Config_Key = 'WC_Batch_Shelf_Life_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = wc.Construct AND Config_Key = 'WC_Batch_Shelf_Life_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
            (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'WC_Batch_Shelf_Life_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
        ) AS INT),
        MRP_IssueDate
    ) AS Batch_Expiry_Date,

    -- ============================================================
    -- Age Calculation for Degradation
    -- Days since issue date
    -- ============================================================
    DATEDIFF(DAY, MRP_IssueDate, GETDATE()) AS Batch_Age_Days,

    -- Row type identifier
    'WC_BATCH' AS Row_Type

FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE
    -- Valid WC batch ID required
    WCID_From_MO IS NOT NULL
    AND WCID_From_MO <> ''
    -- Remaining quantity must be positive
    AND MRP_Remaining_Qty > 0
    -- Partial issuance indicates WC batch in progress
    AND Has_Issued = 'YES'
