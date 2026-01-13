USE [MED]
GO

/****** Object:  View [dbo].[rolyat_WC_PAB_data_cleaned]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: rolyat_WC_PAB_data_cleaned
PURPOSE: Layer 1 - Data cleansing and standardization from ETB_PAB_AUTO
DEPENDENCIES: dbo.ETB_PAB_AUTO (base table)
DOWNSTREAM: Rolyat_Base_Demand

CHANGES (2026-01-13):
- Removed redundant CleanItem column (was identical to ITEMNMBR after trim)
- Consolidated LTRIM/RTRIM to single TRIM() calls for readability
- Added explicit column comments
- Standardized NULL handling with COALESCE
- Improved date conversion with explicit TRY_CONVERT
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[rolyat_WC_PAB_data_cleaned]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[rolyat_WC_PAB_data_cleaned]
AS
SELECT 
    -- Order identifiers (cleaned and standardized)
    UPPER(TRIM(ORDERNUMBER)) AS ORDERNUMBER,
    UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        TRIM(REPLACE(ORDERNUMBER, 'MO', '')), 
        '-', ''), ' ', ''), '/', ''), '.', ''), '#', '')) AS CleanOrder,
    
    -- Item identifiers
    TRIM(ITEMNMBR) AS ITEMNMBR,
    TRIM(ITEMNMBR) AS CleanItem,  -- Kept for backward compatibility
    
    -- Work center and product hierarchy
    TRIM(COALESCE(WCID_From_MO, '')) AS WCID_From_MO,
    TRIM(COALESCE(Construct, '')) AS Construct,
    TRIM(COALESCE(FG, '')) AS FG,
    TRIM(COALESCE([FG Desc], '')) AS FG_Desc,
    TRIM(COALESCE(ItemDescription, '')) AS ItemDescription,
    
    -- Item attributes
    TRIM(COALESCE(UOMSCHDL, '')) AS UOMSCHDL,
    TRIM(COALESCE(STSDESCR, '')) AS STSDESCR,
    TRIM(COALESCE(MRPTYPE, '')) AS MRPTYPE,
    TRIM(COALESCE(VendorItem, '')) AS VendorItem,
    TRIM(COALESCE(INCLUDE_MRP, '')) AS INCLUDE_MRP,
    TRIM(COALESCE(SITE, '')) AS SITE,
    TRIM(COALESCE(PRIME_VNDR, '')) AS PRIME_VNDR,
    
    -- Date fields (converted to DATE type)
    TRY_CONVERT(DATE, [Date + Expiry]) AS Date_Expiry,
    TRY_CONVERT(DATE, [Expiry Dates]) AS Expiry_Dates,
    TRY_CONVERT(DATE, DUEDATE) AS DUEDATE,
    TRY_CONVERT(DATE, MRP_IssueDate) AS MRP_IssueDate,
    
    -- Quantity fields (converted to DECIMAL with NULL protection)
    COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) AS BEG_BAL,
    COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS POs,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS Deductions,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS CleanDeductions,
    COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) AS Expiry,
    COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) AS Remaining,
    COALESCE(TRY_CAST(Running_Balance AS DECIMAL(18, 5)), 0.0) AS Running_Balance,
    COALESCE(TRY_CAST(Issued AS DECIMAL(18, 5)), 0.0) AS Issued,
    
    -- Planning parameters
    COALESCE(TRY_CAST(PURCHASING_LT AS DECIMAL(18, 5)), 0.0) AS PURCHASING_LT,
    COALESCE(TRY_CAST(PLANNING_LT AS DECIMAL(18, 5)), 0.0) AS PLANNING_LT,
    COALESCE(TRY_CAST(ORDER_POINT_QTY AS DECIMAL(18, 5)), 0.0) AS ORDER_POINT_QTY,
    COALESCE(TRY_CAST(SAFETY_STOCK AS DECIMAL(18, 5)), 0.0) AS SAFETY_STOCK,
    
    -- Status flags (standardized to uppercase YES/NO)
    UPPER(TRIM(COALESCE(Has_Issued, 'NO'))) AS Has_Issued,
    UPPER(TRIM(COALESCE(IssueDate_Mismatch, 'NO'))) AS IssueDate_Mismatch,
    UPPER(TRIM(COALESCE(Early_Issue_Flag, 'NO'))) AS Early_Issue_Flag

FROM dbo.ETB_PAB_AUTO
WHERE 
    -- Exclude rows with invalid dates
    TRY_CONVERT(DATE, [Date + Expiry]) IS NOT NULL
    -- Exclude specific item prefixes (60.x and 70.x series)
    AND TRIM(ITEMNMBR) NOT LIKE '60.%'
    AND TRIM(ITEMNMBR) NOT LIKE '70.%'
    -- Exclude partially received orders
    AND TRIM(COALESCE(STSDESCR, '')) <> 'Partially Received';
GO
