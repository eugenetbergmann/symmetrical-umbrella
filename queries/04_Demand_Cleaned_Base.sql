/*******************************************************************************
* View Name:    ETB2_Demand_Cleaned_Base
* Deploy Order: 04 of 17
* 
* Purpose:      Cleaned demand data excluding partial/invalid/cancelled orders
* Grain:        One row per item per demand date (aggregated)
* 
* Dependencies:
*   ✓ dbo.ETB_PAB_AUTO (demand data - external table)
*   ✓ dbo.Prosenthal_Vendor_Items (vendor mapping - external table)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Demand_Cleaned_Base
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.ITEMNMBR,
    d.DUEDAT AS Demand_Date,
    SUM(d.QTYORDER) AS Quantity,  -- Aggregated quantity per item per date
    COALESCE(v.CUSTNMBR, 'UNKNOWN') AS Campaign_ID,  -- Campaign reference from vendor items
    'ETB_PAB_AUTO' AS Source_System,
    COUNT(*) AS Order_Line_Count  -- Line count for data quality check
FROM dbo.ETB_PAB_AUTO d
LEFT JOIN dbo.Prosenthal_Vendor_Items v ON d.ITEMNMBR = v.ITEMNMBR
WHERE d.POSTATUS <> 'CANCELLED'  -- Exclude cancelled orders
    AND d.QTYORDER > 0            -- Exclude zero/negative quantities
    AND d.SOPTYPE NOT IN (60, 70) -- Exclude partial/receive order types
GROUP BY d.ITEMNMBR, d.DUEDAT, v.CUSTNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
