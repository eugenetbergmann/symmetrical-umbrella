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

WITH SurplusInventory AS (
    SELECT 
        pib.ITEMNMBR AS Item_Number,
        pib.LOCNID AS From_Work_Center,
        SUM(COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0)) AS Surplus_Qty,
        -- FG SOURCE (PAB-style): Carry FG from inventory view if available
        MAX(i.FG_Item_Number) AS FG_Item_Number,
        MAX(i.FG_Description) AS FG_Description,
        MAX(i.Construct) AS Construct
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
    LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) 
        ON LTRIM(RTRIM(pib.ITEMNMBR)) = i.Item_Number
        AND pib.LOCNID = i.Site
    WHERE COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0) > 0 
      AND pib.LOCNID LIKE 'WC[_-]%'
    GROUP BY pib.ITEMNMBR, pib.LOCNID
),

DeficitDemand AS (
    SELECT 
        d.Item_Number,
        i.Site AS To_Work_Center,
        SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS Deficit_Qty,
        -- FG SOURCE (PAB-style): Carry FG from demand view
        MAX(d.FG_Item_Number) AS FG_Item_Number,
        MAX(d.FG_Description) AS FG_Description,
        MAX(d.Construct) AS Construct
    FROM dbo.ETB2_Demand_Cleaned_Base d WITH (NOLOCK)
    LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) 
        ON d.Item_Number = i.Item_Number
    WHERE d.Is_Within_Active_Planning_Window = 1
    GROUP BY d.Item_Number, i.Site
    HAVING SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) > 0
)

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
    GETDATE() AS Identified_Date,
    -- FG SOURCE (PAB-style): Coalesce from surplus and deficit sources
    COALESCE(Surplus.FG_Item_Number, Deficit.FG_Item_Number) AS FG_Item_Number,
    COALESCE(Surplus.FG_Description, Deficit.FG_Description) AS FG_Description,
    -- Construct SOURCE (PAB-style): Coalesce from surplus and deficit sources
    COALESCE(Surplus.Construct, Deficit.Construct) AS Construct
FROM SurplusInventory Surplus
INNER JOIN DeficitDemand Deficit 
    ON Surplus.Item_Number = Deficit.Item_Number;

-- ============================================================================
-- END OF VIEW 10
-- ============================================================================
