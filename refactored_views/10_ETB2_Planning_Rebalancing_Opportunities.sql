-- ============================================================================
-- VIEW 10: dbo.ETB2_Planning_Rebalancing_Opportunities
-- Deploy Order: 10 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Identify inventory rebalancing opportunities between work centers
-- Grain: One row per item per surplus/deficit location pair
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Planning_Rebalancing_Opportunities
-- ============================================================================

SELECT 
    Surplus.Item_Number,
    Surplus.From_Work_Center,
    Surplus.Surplus_Qty,
    Deficit.To_Work_Center,
    Deficit.Deficit_Qty,
    CASE 
        WHEN Surplus.Surplus_Qty < Deficit.Deficit_Qty 
        THEN Surplus.Surplus_Qty 
        ELSE Deficit.Deficit_Qty 
    END AS Recommended_Transfer,
    Surplus.Surplus_Qty - Deficit.Deficit_Qty AS Net_Position,
    'TRANSFER' AS Rebalancing_Type,
    GETDATE() AS Identified_Date
FROM (
    SELECT 
        pib.ITEMNMBR AS Item_Number,
        pib.LOCNID AS From_Work_Center,
        SUM(COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0)) AS Surplus_Qty
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
    WHERE COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0) > 0 
      AND pib.LOCNID LIKE 'WC[_-]%'
    GROUP BY pib.ITEMNMBR, pib.LOCNID
) Surplus
INNER JOIN (
    SELECT 
        d.Item_Number,
        i.Site AS To_Work_Center,
        SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS Deficit_Qty
    FROM dbo.ETB2_Demand_Cleaned_Base d WITH (NOLOCK)
    LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) ON d.Item_Number = i.Item_Number
    WHERE d.Is_Within_Active_Planning_Window = 1
    GROUP BY d.Item_Number, i.Site
    HAVING SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) > 0
) Deficit ON Surplus.Item_Number = Deficit.Item_Number;

-- ============================================================================
-- END OF VIEW 10
-- ============================================================================
