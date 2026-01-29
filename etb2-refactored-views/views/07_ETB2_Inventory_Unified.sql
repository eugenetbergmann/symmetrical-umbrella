-- ============================================================================
-- VIEW 07: dbo.ETB2_Inventory_Unified (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: All eligible inventory consolidated (WC + released holds)
-- Grain: Item/Lot
-- Dependencies:
--   - dbo.ETB2_Inventory_WC_Batches (view 05)
--   - dbo.ETB2_Inventory_Quarantine_Restricted (view 06)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all UNION parts
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
-- Last Updated: 2026-01-29
-- ============================================================================

-- WC Batches (always eligible)
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    'WC' AS Site_Type,
    Quantity,
    Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    Days_To_Expiry,
    Use_Sequence,
    'AVAILABLE' AS Inventory_Type,
    1 AS Allocation_Priority,  -- WC first
    
    -- Suppression flag
    Is_Suppressed
    
FROM dbo.ETB2_Inventory_WC_Batches WITH (NOLOCK)
WHERE Is_Suppressed = 0

UNION ALL

-- WFQ Batches (released only)
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    Hold_Type AS Site_Type,
    Quantity,
    Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,
    Use_Sequence,
    'QUARANTINE_WFQ' AS Inventory_Type,
    2 AS Allocation_Priority,  -- After WC
    
    -- Suppression flag
    Is_Suppressed
    
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'WFQ'
  AND Can_Allocate = 1
  AND Is_Suppressed = 0

UNION ALL

-- RMQTY Batches (released only)
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    Hold_Type AS Site_Type,
    Quantity,
    Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,
    Use_Sequence,
    'RESTRICTED_RMQTY' AS Inventory_Type,
    3 AS Allocation_Priority,  -- After WFQ
    
    -- Suppression flag
    Is_Suppressed
    
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'RMQTY'
  AND Can_Allocate = 1
  AND Is_Suppressed = 0;

-- ============================================================================
-- END OF VIEW 07 (REFACTORED)
-- ============================================================================