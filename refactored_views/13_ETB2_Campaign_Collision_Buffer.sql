-- ============================================================================
-- VIEW 13: dbo.ETB2_Campaign_Collision_Buffer
-- Deploy Order: 13 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Calculate collision buffer requirements based on concurrency
-- Grain: One row per campaign per item with collision risk
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Collision_Buffer
-- ============================================================================

SELECT 
    n.Campaign_ID,
    n.Item_Number,
    n.Total_Campaign_Quantity,
    n.CCU,
    COALESCE(SUM(w.Combined_CCU) * 0.20, 0) AS collision_buffer_qty,
    n.Peak_Period_Start,
    n.Peak_Period_End,
    CASE 
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Collision_Risk_Level,
    COUNT(w.Campaign_B) AS Overlapping_Campaigns
FROM dbo.ETB2_Campaign_Normalized_Demand n WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Campaign_Concurrency_Window w WITH (NOLOCK) 
    ON (n.Campaign_ID = w.Campaign_A OR n.Campaign_ID = w.Campaign_B)
    AND n.Item_Number = w.Item_Number
GROUP BY n.Campaign_ID, n.Item_Number, n.Total_Campaign_Quantity, n.CCU,
         n.Peak_Period_Start, n.Peak_Period_End;

-- ============================================================================
-- END OF VIEW 13
-- ============================================================================
