/*******************************************************************************
* View Name:    ETB2_Planning_Net_Requirements
* Deploy Order: 09 of 17
* 
* Purpose:      Net procurement requirements calculation with lead time adjustments
* Grain:        One row per item
* 
* Dependencies:
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04)
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05)
*   ✓ dbo.ETB2_Config_Active (view 03)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Planning_Net_Requirements
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Planning_Net_Requirements
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.ITEMNMBR,
    SUM(d.Quantity) AS Gross_Demand,
    COALESCE(SUM(i.Quantity), 0) AS On_Hand_Inventory,
    SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) AS Net_Requirement,  -- Positive = shortage
    COALESCE(c.Lead_Time_Days, 30) AS Lead_Time_Days,
    -- Recommended order: net requirement + 10% safety stock
    CASE 
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) > 0 
        THEN (SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0)) * 1.1 
        ELSE 0 
    END AS Recommended_Order_Qty,
    -- Priority based on shortage magnitude
    CASE 
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) > 1000 THEN 1  -- Critical
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) > 500 THEN 2  -- High
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) > 0 THEN 3    -- Medium
        ELSE 4                                                             -- None
    END AS Priority_Score,
    CASE 
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) > 0 THEN 'PROCURE'
        ELSE 'SATISFIED'
    END AS Action_Required,
    -- Order date to meet demand by lead time
    DATEADD(DAY, -COALESCE(c.Lead_Time_Days, 30), MIN(d.Demand_Date)) AS Order_By_Date
FROM dbo.ETB2_Demand_Cleaned_Base d
LEFT JOIN dbo.ETB2_Inventory_WC_Batches i ON d.ITEMNMBR = i.ITEMNMBR
LEFT JOIN dbo.ETB2_Config_Active c ON d.ITEMNMBR = c.ITEMNMBR
GROUP BY d.ITEMNMBR, c.Lead_Time_Days

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
