/*******************************************************************************
* View Name:    ETB2_Campaign_Absorption_Capacity
* Deploy Order: 15 of 17
* 
* Purpose:      Executive KPI - number of campaigns that can be absorbed
* Grain:        One row per item
* 
* Dependencies:
*   ✓ dbo.ETB2_Campaign_Collision_Buffer (view 13)
*   ✓ dbo.ETB2_Campaign_Risk_Adequacy (view 14)
*   ✓ dbo.ETB2_Config_Active (view 03)
*   ✓ dbo.ETB2_Config_Part_Pooling (view 02)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Campaign_Absorption_Capacity
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Campaign_Absorption_Capacity
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    b.ITEMNMBR,
    COUNT(DISTINCT b.Campaign_ID) AS Total_Campaigns,
    -- Absorbable campaigns = total buffer required / available buffer per campaign
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(SUM(b.collision_buffer_qty) / AVG(b.CCU) AS INT)
        ELSE COUNT(DISTINCT b.Campaign_ID)
    END AS absorbable_campaigns,
    SUM(b.collision_buffer_qty) AS Total_Buffer_Required,
    AVG(b.CCU) AS Avg_Campaign_Consumption,
    -- Utilization percentage
    CASE 
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 5 THEN 1.0
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 3 THEN 0.7
        ELSE 0.4
    END AS Utilization_Pct,
    -- Risk status color coding
    CASE 
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 5 THEN 'GREEN'
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 3 THEN 'YELLOW'
        ELSE 'RED'
    END AS Risk_Status,
    -- Capacity assessment
    CASE 
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 5 THEN 'HIGH_CAPACITY'
        WHEN COUNT(DISTINCT b.Campaign_ID) >= 3 THEN 'MODERATE_CAPACITY'
        ELSE 'LOW_CAPACITY'
    END AS Capacity_Classification
FROM dbo.ETB2_Campaign_Collision_Buffer b
GROUP BY b.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
