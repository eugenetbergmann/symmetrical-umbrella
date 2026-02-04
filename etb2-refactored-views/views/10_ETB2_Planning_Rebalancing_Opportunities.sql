-- ============================================================================
-- VIEW 10: dbo.ETB2_Planning_Rebalancing_Opportunities (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Identify inventory rebalancing opportunities between work centers
-- Grain: One row per item per surplus/deficit location pair
-- Dependencies:
--   - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (external table)
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
--   - dbo.ETB2_Inventory_Unified (view 07)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct coalesced from surplus/deficit sources
--   - Is_Suppressed flag
-- Last Updated: 2026-01-30
-- ============================================================================

WITH SurplusInventory AS (
    SELECT 
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,
        
        pib.ITEMNMBR AS item_number,
        NULL AS customer_number,
        pib.LOCNID AS From_Work_Center,
        SUM(COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0)) AS Surplus_Qty,
        
        -- FG SOURCE (PAB-style): Carry FG from inventory view if available
        MAX(i.FG_Item_Number) AS FG_Item_Number,
        MAX(i.FG_Description) AS FG_Description,
        MAX(i.Construct) AS Construct,
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed
        
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
    LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) 
        ON LTRIM(RTRIM(pib.ITEMNMBR)) = i.Item_Number
        AND pib.LOCNID = i.Site
    WHERE COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0) > 0 
      AND pib.LOCNID LIKE 'WC[_-]%'
      AND pib.ITEMNMBR NOT LIKE 'MO-%'
      AND CAST(GETDATE() AS DATE) BETWEEN 
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    GROUP BY pib.ITEMNMBR, pib.LOCNID
),

DeficitDemand AS (
    SELECT 
        -- Context columns
        d.client,
        d.contract,
        d.run,
        
        d.item_number,
        d.customer_number,
        i.Site AS To_Work_Center,
        SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS Deficit_Qty,
        
        -- FG SOURCE (PAB-style): Carry FG from demand view
        MAX(d.FG_Item_Number) AS FG_Item_Number,
        MAX(d.FG_Description) AS FG_Description,
        MAX(d.Construct) AS Construct,
        
        -- Suppression flag (aggregate)
        MAX(CASE WHEN d.Is_Suppressed = 1 OR COALESCE(i.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) AS Is_Suppressed
        
    FROM dbo.ETB2_Demand_Cleaned_Base d WITH (NOLOCK)
    LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) 
        ON d.item_number = i.item_number
        AND d.customer_number = i.customer_number
        AND d.client = i.client
        AND d.contract = i.contract
        AND d.run = i.run
    WHERE d.Is_Within_Active_Planning_Window = 1
      AND d.Item_Number NOT LIKE 'MO-%'
    GROUP BY d.client, d.contract, d.run, d.Item_Number, i.Site
    HAVING SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) > 0
)

SELECT 
    -- Context columns preserved
    Surplus.client,
    Surplus.contract,
    Surplus.run,
    
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
    COALESCE(Surplus.Construct, Deficit.Construct) AS Construct,
    
    -- Suppression flag
    CAST(Surplus.Is_Suppressed | Deficit.Is_Suppressed AS BIT) AS Is_Suppressed
    
FROM SurplusInventory Surplus
INNER JOIN DeficitDemand Deficit 
    ON Surplus.Item_Number = Deficit.Item_Number
    AND Surplus.client = Deficit.client
    AND Surplus.contract = Deficit.contract
    AND Surplus.run = Deficit.run
WHERE CAST(Surplus.Is_Suppressed | Deficit.Is_Suppressed AS BIT) = 0;

-- ============================================================================
-- END OF VIEW 10 (CONSOLIDATED FINAL)
-- ============================================================================
