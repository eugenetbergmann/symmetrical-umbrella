/*******************************************************************************
* View Name:    ETB2_Planning_Stockout_Risk
* Deploy Order: 08 of 17
* 
* Purpose:      ATP (Available to Promise) balance and stockout risk classification
* Grain:        One row per item
* 
* Dependencies:
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04)
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Planning_Stockout_Risk
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Planning_Stockout_Risk
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.ITEMNMBR,
    SUM(d.Quantity) AS Projected_Demand,
    COALESCE(SUM(i.Quantity), 0) AS Current_Inventory,
    SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) AS ATP,  -- ATP = Demand - Inventory
    CASE 
        -- CRITICAL: Negative ATP (stockout imminent)
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) < 0 THEN 'CRITICAL'
        -- HIGH: ATP < 50% of demand
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) < SUM(d.Quantity) * 0.5 THEN 'HIGH'
        -- MEDIUM: ATP < 100% of demand
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) < SUM(d.Quantity) THEN 'MEDIUM'
        -- LOW: ATP >= demand
        ELSE 'LOW'
    END AS Risk_Classification,
    CASE 
        WHEN SUM(d.Quantity) > 0 
        THEN CAST(COALESCE(SUM(i.Quantity), 0) AS DECIMAL(10,2)) / SUM(d.Quantity)
        ELSE 1.0
    END AS Service_Level_Pct,
    -- Days of supply based on average daily demand
    CASE 
        WHEN SUM(d.Quantity) > 0 
        THEN CAST(COALESCE(SUM(i.Quantity), 0) / (SUM(d.Quantity) / 30) AS INT)
        ELSE 999
    END AS Days_Of_Supply
FROM dbo.ETB2_Demand_Cleaned_Base d
LEFT JOIN dbo.ETB2_Inventory_WC_Batches i ON d.ITEMNMBR = i.ITEMNMBR
GROUP BY d.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
