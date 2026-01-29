-- ============================================================================
-- VIEW 15: dbo.ETB2_Campaign_Absorption_Capacity (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Executive KPI - campaign absorption capacity vs inventory
-- Grain: One row per campaign item (aggregated)
-- Dependencies:
--   - dbo.ETB2_Campaign_Risk_Adequacy (view 14)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Context preserved in subqueries
-- Last Updated: 2026-01-29
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
    
    -- Suppression flag (aggregate - if any suppressed, mark all)
    MAX(CASE WHEN r.Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Is_Suppressed
    
FROM dbo.ETB2_Campaign_Risk_Adequacy r WITH (NOLOCK)
WHERE r.Item_Number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
GROUP BY r.client, r.contract, r.run, r.Campaign_ID
HAVING MAX(CASE WHEN r.Is_Suppressed = 1 THEN 1 ELSE 0 END) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 15 (REFACTORED)
-- ============================================================================