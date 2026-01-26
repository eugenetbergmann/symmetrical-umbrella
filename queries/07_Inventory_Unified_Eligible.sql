/*******************************************************************************
 * View Name:    ETB2_Inventory_Unified_Eligible
 * Deploy Order: 07 of 17
 * Status:       🔴 NOT YET DEPLOYED
 * 
 * Purpose:      WC inventory eligible to fulfill demand within time fence
 * Grain:        One row per item per work center (aggregated)
 * 
 * Business Logic:
 *   - Only includes WC inventory (NOT WFQ/quarantine)
 *   - Inventory must not be expired
 *   - WC inventory can fulfill demand if not expired
 *   - WFQ (Wait For Quality) is separate and only used during stockouts
 * 
 * Dependencies (MUST exist - verify first):
 *   ✅ ETB2_Config_Lead_Times (deployed)
 *   ✅ ETB2_Config_Part_Pooling (deployed)
 *   ✅ ETB2_Config_Active (deployed)
 *   ✓ dbo.ETB_Inventory_WC (WC inventory - external table)
 *
 * ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
 * 1. Object Explorer → Right-click "Views" → "New View..."
 * 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
 * 3. Delete default SQL
 * 4. Copy SELECT below (between markers)
 * 5. Paste into SQL pane
 * 6. Execute (!) to test
 * 7. Save as: dbo.ETB2_Inventory_Unified_Eligible
 * 8. Refresh Views folder
 *
 * Validation: 
 *   SELECT COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible
 *   Expected: Non-expired WC inventory rows
 *******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    i.ITEMNMBR,
    i.Work_Center,
    SUM(i.Quantity) AS Eligible_Qty,
    MIN(i.Expiry_Date) AS Earliest_Expiry,
    MIN(i.DATERECD) AS Date_In_Bin,  -- Date inventory was received into bin
    COUNT(*) AS Batch_Count,
    'WC' AS Inventory_Source,
    -- Expiry status for filtering
    CASE 
        WHEN i.Expiry_Date >= GETDATE() THEN 'VALID'
        ELSE 'EXPIRED'
    END AS Expiry_Status
FROM dbo.ETB_Inventory_WC i
WHERE i.Expiry_Date >= GETDATE()  -- Only non-expired inventory
    AND i.Quantity > 0
GROUP BY i.ITEMNMBR, i.Work_Center, 
    CASE WHEN i.Expiry_Date >= GETDATE() THEN 'VALID' ELSE 'EXPIRED' END
    'UNIFIED' AS Inventory_Source
FROM dbo.ETB_Inventory_WC
WHERE ITEMNMBR NOT IN (
    -- Exclude items that are in quarantine/restricted
    SELECT ITEMNMBR FROM dbo.ETB2_Inventory_Quarantine_Restricted
)
GROUP BY ITEMNMBR, Work_Center

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
 * WFQ (Wait For Quality) / Quarantine Inventory - SEPARATE CONCEPT:
 * 
 * WFQ = Material awaiting release (testing, inspection, quality hold)
 * Location: NOT in WC (typically in QC or quarantine zones)
 * 
 * WFQ should ONLY be used when:
 *   - A stockout is occurring or imminent
 *   - We need to check if quarantined material can be released
 *   - Emergency supply scenario
 * 
 * Normal demand fulfillment:
 *   - Use WC inventory only (this view)
 *   - Check expiry date (must not be expired)
 * 
 * Stockout scenario:
 *   - Check WFQ inventory via dbo.ETB2_Inventory_Quarantine_Restricted
 *   - Evaluate if material can be released for use
 * 
 * Post-Deployment Validation:
 * 
 * 1. Row count check:
 *    SELECT COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible
 *    -- Should show non-expired WC inventory
 * 
 * 2. Expiry status check:
 *    SELECT Expiry_Status, COUNT(*) AS Rows, SUM(Eligible_Qty) AS Qty
 *    FROM dbo.ETB2_Inventory_Unified_Eligible
 *    GROUP BY Expiry_Status
 *    -- VALID = can fulfill demand, EXPIRED = needs replacement
 * 
 * 3. Work center distribution:
 *    SELECT 
 *        Work_Center,
 *        COUNT(DISTINCT ITEMNMBR) AS Unique_Items,
 *        SUM(Eligible_Qty) AS Total_Qty
 *    FROM dbo.ETB2_Inventory_Unified_Eligible
 *    GROUP BY Work_Center
 *    ORDER BY Work_Center
 */
