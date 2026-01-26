/*******************************************************************************
* View Name:    ETB2_Planning_Net_Requirements
* Deploy Order: 09 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Calculate net procurement requirements after accounting for inventory
* Grain:        One row per item per demand period
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04 - deploy first)
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05 - deploy first)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Planning_Net_Requirements
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Planning_Net_Requirements
*   Expected: Net requirements per item
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.ITEMNMBR,
    d.Demand_Date,
    SUM(d.Quantity) AS Gross_Demand,
    COALESCE(SUM(i.Quantity), 0) AS Available_Inventory,
    SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) AS Net_Requirement,
    CASE 
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) > 0 
        THEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0)
        ELSE 0 
    END AS Procurement_Qty,
    CASE 
        WHEN COALESCE(SUM(i.Quantity), 0) >= SUM(d.Quantity) 
        THEN 'COVERED'
        ELSE 'PROCURE'
    END AS Requirement_Status,
    GETDATE() AS Calculated_Date
FROM dbo.ETB2_Demand_Cleaned_Base d
LEFT JOIN dbo.ETB2_Inventory_WC_Batches i ON d.ITEMNMBR = i.ITEMNMBR
GROUP BY d.ITEMNMBR, d.Demand_Date

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Requirement summary:
   SELECT 
       Requirement_Status,
       COUNT(*) AS Items,
       SUM(Procurement_Qty) AS Total_Procurement
   FROM dbo.ETB2_Planning_Net_Requirements
   GROUP BY Requirement_Status

2. Top procurement needs:
   SELECT TOP 10
       ITEMNMBR,
       SUM(Procurement_Qty) AS Total_Procurement_Needed
   FROM dbo.ETB2_Planning_Net_Requirements
   WHERE Procurement_Qty > 0
   GROUP BY ITEMNMBR
   ORDER BY Total_Procurement_Needed DESC

3. Time-phased requirements:
   SELECT 
       DATEPART(YEAR, Demand_Date) AS Year,
       DATEPART(MONTH, Demand_Date) AS Month,
       SUM(Procurement_Qty) AS Monthly_Procurement
   FROM dbo.ETB2_Planning_Net_Requirements
   WHERE Procurement_Qty > 0
   GROUP BY DATEPART(YEAR, Demand_Date), DATEPART(MONTH, Demand_Date)
   ORDER BY Year, Month
*/
