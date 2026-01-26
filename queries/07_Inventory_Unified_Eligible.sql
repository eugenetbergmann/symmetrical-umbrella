/*******************************************************************************
* View Name:    ETB2_Inventory_Unified_Eligible
* Deploy Order: 07 of 17
* 
* Purpose:      All eligible inventory consolidated (WC batches + released quarantine)
* Grain:        One row per item per source type per location
* 
* Dependencies:
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05)
*   ✓ dbo.ETB2_Inventory_Quarantine_Restricted (view 06)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Inventory_Unified_Eligible
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

-- Part A: Work Center batches (FEFO-ranked, eligible for use)
SELECT 
    ITEMNMBR,
    'WC_Batch' AS Source_Type,
    Work_Center AS Location,
    Quantity AS Available_Qty,
    Batch_Number,
    Expiry_Date,
    FEFO_Rank,
    'Eligible' AS Status
FROM dbo.ETB2_Inventory_WC_Batches
WHERE FEFO_Rank <= 5 OR FEFO_Rank = 0  -- Top 5 FEFO or non-FEFO enabled

UNION ALL

-- Part B: Released quarantine inventory (hold period expired)
SELECT 
    ITEMNMBR,
    'Quarantine_Released' AS Source_Type,
    Location,
    Available_Qty,
    Receipt_Reference AS Batch_Number,
    NULL AS Expiry_Date,  -- Quarantine items may not have expiry
    999 AS FEFO_Rank,     -- Always last in FEFO ordering
    'Released' AS Status
FROM dbo.ETB2_Inventory_Quarantine_Restricted
WHERE Hold_Until <= GETDATE()  -- Only released (hold period expired)

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
