/*******************************************************************************
* View Name:    ETB2_Demand_Cleaned_Base
* Deploy Order: 04 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Cleaned demand data excluding partial/invalid/cancelled orders
* Grain:        One row per item per demand date (aggregated)
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB_PAB_AUTO (demand data - external table)
*   ✓ dbo.Prosenthal_Vendor_Items (vendor mapping - external table)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Demand_Cleaned_Base
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
*   Expected: Rows matching orders in ETB_PAB_AUTO (excluding cancelled, 60.x, 70.x)
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.ITEMNMBR,
    d.DUEDATE AS Demand_Date,
    SUM(d.[amount on order]) AS Quantity,  -- Aggregated quantity per item per date (update column name as needed)
    COALESCE(d.Construct, 'UNKNOWN') AS Campaign_ID,  -- Campaign reference from Construct column
    'ETB_PAB_AUTO' AS Source_System,
    COUNT(*) AS Order_Line_Count  -- Line count for data quality check
FROM dbo.ETB_PAB_AUTO d
WHERE d.MRPTYPE NOT IN (60, 70) -- Use MRPTYPE for order type filtering
GROUP BY d.ITEMNMBR, d.DUEDATE, d.Construct

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Row count check:
   SELECT COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
   -- Should be less than ETB_PAB_AUTO (due to filtering)

2. Data quality check:
   SELECT TOP 10 
       ITEMNMBR,
       Demand_Date,
       Quantity,
       Campaign_ID
   FROM dbo.ETB2_Demand_Cleaned_Base
   ORDER BY Demand_Date DESC
   -- Should show no cancelled orders, no 60.x/70.x items

3. Campaign coverage:
   SELECT 
       COUNT(*) AS Total_Items,
       COUNT(DISTINCT Campaign_ID) AS Unique_Campaigns
   FROM dbo.ETB2_Demand_Cleaned_Base
   WHERE Campaign_ID <> 'UNKNOWN'
*/
