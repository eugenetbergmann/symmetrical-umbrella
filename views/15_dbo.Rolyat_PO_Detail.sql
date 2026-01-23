/*
===============================================================================
View: dbo.Rolyat_PO_Detail
Description: Purchase order details aggregated by item and site
Version: 1.0.0
Last Modified: 2026-01-20
Dependencies:
   - dbo.ETB_PAB_AUTO

Purpose:
   - Provides PO supply information per item/site
   - Distinguishes between total PO supply and released PO supply
   - Supports ATP vs Forecast calculations

Business Rules:
   - Total_PO_Supply: All PO quantities
   - Released_PO_Supply: POs that are released but not fully received
   - Currently assumes all POs are released and not fully received
===============================================================================
*/

SELECT
    TRIM(ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(SITE, '')) AS Site_ID,
    -- Total PO quantity
    COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS PO_Qty,
    -- Open PO quantity (assuming not fully received)
    COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS Open_PO_Qty,
    -- PO due date (parse from JSON)
    TRY_CONVERT(DATE, JSON_VALUE([Date + Expiry], '$.date')) AS PO_Due_Date,
    -- Assuming all POs are released for now
    1 AS Is_Released,
    -- Assuming no POs are fully received for now
    0 AS Is_Fully_Received

FROM dbo.ETB_PAB_AUTO
WHERE
    -- Valid PO quantity
    TRY_CAST([PO's] AS DECIMAL(18, 5)) > 0
    -- Exclude invalid JSON or missing date
    AND ISJSON([Date + Expiry]) = 1
    AND TRY_CONVERT(DATE, JSON_VALUE([Date + Expiry], '$.date')) IS NOT NULL
    -- Exclude specific item prefixes
    AND TRIM(ITEMNMBR) NOT LIKE '60.%'
    AND TRIM(ITEMNMBR) NOT LIKE '70.%'
    -- Exclude partially received orders
    AND TRIM(COALESCE(STSDESCR, '')) <> 'Partially Received'