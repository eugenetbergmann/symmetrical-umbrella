-- ============================================================================
-- VIEW 15: dbo.ETB2_Campaign_Absorption_Capacity
-- Deploy Order: 15 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Executive KPI - campaign absorption capacity vs inventory
-- Grain: One row per campaign item (aggregated)
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Absorption_Capacity
-- ============================================================================

SELECT 
    r.Campaign_ID,
    SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) AS Total_Inventory,
    SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) AS Total_Buffer_Required,
    CASE 
        WHEN SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) > 0 
        THEN CAST(SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) AS DECIMAL(10,2)) / SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0))
        ELSE 1.0
    END AS Absorption_Ratio,
    CASE 
        WHEN SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) < SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) * 0.5 THEN 'CRITICAL'
        WHEN SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) < SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) THEN 'AT_RISK'
        WHEN SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) < SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) * 1.5 THEN 'HEALTHY'
        ELSE 'OVER_STOCKED'
    END AS Campaign_Health,
    COUNT(DISTINCT r.Item_Number) AS Items_In_Campaign,
    AVG(COALESCE(TRY_CAST(r.Adequacy_Score AS DECIMAL(10,2)), 0)) AS Avg_Adequacy,
    GETDATE() AS Calculated_Date,
    -- FG SOURCE (PAB-style): Carry primary FG from first item in campaign
    MAX(r.FG_Item_Number) AS FG_Item_Number,
    MAX(r.FG_Description) AS FG_Description,
    -- Construct SOURCE (PAB-style): Carry primary Construct from first item in campaign
    MAX(r.Construct) AS Construct
FROM dbo.ETB2_Campaign_Risk_Adequacy r WITH (NOLOCK)
GROUP BY r.Campaign_ID;

-- ============================================================================
-- END OF VIEW 15
-- ============================================================================
