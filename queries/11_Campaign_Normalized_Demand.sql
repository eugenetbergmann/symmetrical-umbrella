/*******************************************************************************
* View Name:    ETB2_Campaign_Normalized_Demand
* Deploy Order: 11 of 17
* 
* Purpose:      Campaign Consumption Units (CCU) - normalized demand per campaign
* Grain:        One row per campaign per item
* 
* Dependencies:
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Campaign_Normalized_Demand
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Campaign_Normalized_Demand
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.Campaign_ID,
    d.ITEMNMBR,
    SUM(d.Quantity) AS Total_Campaign_Quantity,
    SUM(d.Quantity) / 30.0 AS CCU,  -- Campaign Consumption Unit: daily average
    'DAILY' AS CCU_Unit,
    MIN(d.Demand_Date) AS Peak_Period_Start,
    MAX(d.Demand_Date) AS Peak_Period_End,
    DATEDIFF(DAY, MIN(d.Demand_Date), MAX(d.Demand_Date)) AS Campaign_Duration_Days,
    COUNT(DISTINCT d.Demand_Date) AS Active_Days_Count
FROM dbo.ETB2_Demand_Cleaned_Base d
WHERE d.Campaign_ID IS NOT NULL
    AND d.Campaign_ID <> 'UNKNOWN'
GROUP BY d.Campaign_ID, d.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
