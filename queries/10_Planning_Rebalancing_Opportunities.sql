/*******************************************************************************
* View Name:    ETB2_Planning_Rebalancing_Opportunities
* Deploy Order: 10 of 17
* 
* Purpose:      Expiry-driven inventory transfer recommendations (≤90 days)
* Grain:        One row per item per source location
* 
* Dependencies:
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04)
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05)
*   ✓ dbo.ETB2_Inventory_Quarantine_Restricted (view 06)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Planning_Rebalancing_Opportunities
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Planning_Rebalancing_Opportunities
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    i.ITEMNMBR,
    i.Work_Center AS Source_Location,
    -- Find locations with demand for this item
    d.Demand_Date AS Target_Location_Date,
    -- Transfer 50% of excess batch that expires soon
    CASE 
        WHEN i.Quantity > 100 AND i.Days_To_Expiry < 90 
        THEN i.Quantity * 0.5 
        ELSE 0 
    END AS Recommended_Transfer_Qty,
    i.Days_To_Expiry,
    -- Savings potential: value of avoided waste
    CASE 
        WHEN i.Quantity > 100 AND i.Days_To_Expiry < 90 
        THEN i.Quantity * 10  -- Placeholder for unit cost
        ELSE 0 
    END AS Savings_Potential,
    CASE 
        WHEN i.Quantity > 100 AND i.Days_To_Expiry < 90 THEN 'URGENT'
        WHEN i.Days_To_Expiry < 120 THEN 'WATCH'
        ELSE 'OK'
    END AS Transfer_Priority,
    -- Suggested action
    CASE 
        WHEN i.Quantity > 100 AND i.Days_To_Expiry < 90 THEN 'TRANSFER_HALF'
        ELSE 'MONITOR'
    END AS Recommended_Action
FROM dbo.ETB2_Inventory_WC_Batches i
CROSS JOIN dbo.ETB2_Demand_Cleaned_Base d
WHERE i.ITEMNMBR = d.ITEMNMBR
    AND i.FEFO_Rank > 3  -- Lower priority batches (not expiring soonest)
    AND i.Days_To_Expiry IS NOT NULL

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
