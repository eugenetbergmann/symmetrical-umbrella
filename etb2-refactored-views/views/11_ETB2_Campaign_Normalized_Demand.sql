-- ============================================================================
-- VIEW 11: dbo.ETB2_Campaign_Normalized_Demand (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Campaign Consumption Units (CCU) - normalized demand per campaign
-- Grain: One row per campaign per item
-- Dependencies:
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window expanded to ±90 days
-- Last Updated: 2026-01-29
-- ============================================================================

SELECT 
    -- Context columns preserved
    d.client,
    d.contract,
    d.run,
    
    d.Order_Number AS Campaign_ID,
    d.Item_Number,
    SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) AS Total_Campaign_Quantity,
    SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) / 30.0 AS CCU,
    'DAILY' AS CCU_Unit,
    MIN(d.Due_Date) AS Peak_Period_Start,
    MAX(d.Due_Date) AS Peak_Period_End,
    DATEDIFF(DAY, MIN(d.Due_Date), MAX(d.Due_Date)) AS Campaign_Duration_Days,
    COUNT(DISTINCT d.Due_Date) AS Active_Days_Count,
    
    -- Suppression flag (aggregate - if any suppressed, mark all)
    MAX(CASE WHEN d.Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Is_Suppressed
    
FROM dbo.ETB2_Demand_Cleaned_Base d WITH (NOLOCK)
WHERE d.Is_Within_Active_Planning_Window = 1
  AND d.Item_Number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
GROUP BY d.client, d.contract, d.run, d.Order_Number, d.Item_Number
HAVING MAX(CASE WHEN d.Is_Suppressed = 1 THEN 1 ELSE 0 END) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 11 (REFACTORED)
-- ============================================================================