-- ============================================================================
-- VIEW 11: dbo.ETB2_Campaign_Normalized_Demand
-- Deploy Order: 11 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Campaign Consumption Units (CCU) - normalized demand per campaign
-- Grain: One row per campaign per item
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Normalized_Demand
-- ============================================================================

SELECT 
    d.Order_Number AS Campaign_ID,
    d.Item_Number,
    SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) AS Total_Campaign_Quantity,
    SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) / 30.0 AS CCU,
    'DAILY' AS CCU_Unit,
    MIN(d.Due_Date) AS Peak_Period_Start,
    MAX(d.Due_Date) AS Peak_Period_End,
    DATEDIFF(DAY, MIN(d.Due_Date), MAX(d.Due_Date)) AS Campaign_Duration_Days,
    COUNT(DISTINCT d.Due_Date) AS Active_Days_Count
FROM dbo.ETB2_Demand_Cleaned_Base d WITH (NOLOCK)
WHERE d.Is_Within_Active_Planning_Window = 1
GROUP BY d.Order_Number, d.Item_Number;

-- ============================================================================
-- END OF VIEW 11
-- ============================================================================
