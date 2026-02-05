/* VIEW 15 - STATUS: VALIDATED */
-- ============================================================================
-- VIEW 15: dbo.ETB2_Campaign_Absorption_Capacity (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Executive KPI - campaign absorption capacity vs inventory
-- Grain: One row per campaign item (aggregated)
-- Dependencies:
--   - dbo.ETB2_Campaign_Risk_Adequacy (view 14)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct aggregated from risk adequacy (view 14)
--   - Is_Suppressed flag
-- Last Updated: 2026-02-05
-- ============================================================================

SELECT 
    -- Context columns preserved
    r.client,
    r.contract,
    r.run,
    
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
    
    -- FG SOURCE (PAB-style): Carry primary FG from first item in campaign (view 14)
    MAX(r.FG_Item_Number) AS FG_Item_Number,
    MAX(r.FG_Description) AS FG_Description,
    -- Construct SOURCE (PAB-style): Carry primary Construct from first item in campaign (view 14)
    MAX(r.Construct) AS Construct,
    
    -- Suppression flag (aggregate - if any suppressed, mark all)
    MAX(CASE WHEN r.Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Is_Suppressed
    
FROM dbo.ETB2_Campaign_Risk_Adequacy r WITH (NOLOCK)
WHERE r.Item_Number NOT LIKE 'MO-%'
GROUP BY r.client, r.contract, r.run, r.Campaign_ID
HAVING MAX(CASE WHEN r.Is_Suppressed = 1 THEN 1 ELSE 0 END) = 0;

-- ============================================================================
-- END OF VIEW 15 (CONSOLIDATED FINAL)
-- ============================================================================
