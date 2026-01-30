-- ============================================================================
-- VIEW 10: dbo.ETB2_Planning_Rebalancing_Opportunities (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Identify inventory rebalancing opportunities between work centers
-- Grain: One row per item per surplus/deficit location pair
-- Dependencies:
--   - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (external table)
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
--   - dbo.ETB2_Inventory_Unified (view 07)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
--   - Context preserved in subqueries
-- Last Updated: 2026-01-29
-- ============================================================================

SELECT 
    -- Context columns preserved
    Surplus.client,
    Surplus.contract,
    Surplus.run,
    
    Surplus.item_number,
    Surplus.customer_number,
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
    
    -- Suppression flag
    CAST(Surplus.Is_Suppressed | Deficit.Is_Suppressed AS BIT) AS Is_Suppressed
    
FROM (
    SELECT 
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,
        
        pib.ITEMNMBR AS item_number,
        NULL AS customer_number,
        pib.LOCNID AS From_Work_Center,
        SUM(COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0)) AS Surplus_Qty,
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed
        
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
    WHERE COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0) > 0 
      AND pib.LOCNID LIKE 'WC[_-]%'
      AND pib.ITEMNMBR NOT LIKE 'MO-%'  -- Filter out MO- conflated items
      AND CAST(GETDATE() AS DATE) BETWEEN 
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    GROUP BY pib.ITEMNMBR, pib.LOCNID
) Surplus
INNER JOIN (
    SELECT 
        -- Context columns
        d.client,
        d.contract,
        d.run,
        
        d.item_number,
        d.customer_number,
        i.Site AS To_Work_Center,
        SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS Deficit_Qty,
        
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
      AND d.item_number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
    GROUP BY d.client, d.contract, d.run, d.item_number, d.customer_number, i.Site
    HAVING SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) > 0
) Deficit 
    ON Surplus.item_number = Deficit.item_number
    AND Surplus.customer_number = Deficit.customer_number
    AND Surplus.client = Deficit.client
    AND Surplus.contract = Deficit.contract
    AND Surplus.run = Deficit.run
WHERE CAST(Surplus.Is_Suppressed | Deficit.Is_Suppressed AS BIT) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 10 (REFACTORED)
-- ============================================================================