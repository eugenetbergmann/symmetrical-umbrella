-- ============================================================================
-- VIEW 07: dbo.ETB2_Inventory_Unified (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: All eligible inventory consolidated (WC + released holds)
-- Grain: Item/Lot
-- Dependencies:
--   - dbo.ETB2_Inventory_WC_Batches (view 05)
--   - dbo.ETB2_Inventory_Quarantine_Restricted (view 06)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct carried through from source views
--   - Is_Suppressed flag
-- Last Updated: 2026-01-30
-- ============================================================================

-- WC Batches (always eligible)
-- FG/Construct carried through from view 05
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    item_number,
    customer_number,
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
    1 AS Allocation_Priority,
    
    -- Suppression flag
    Is_Suppressed,
    
    -- FG SOURCE (PAB-style): Carried through from view 05
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from view 05
    Construct
    
FROM dbo.ETB2_Inventory_WC_Batches WITH (NOLOCK)
WHERE Is_Suppressed = 0

UNION ALL

-- WFQ Batches (released only)
-- FG/Construct carried through from view 06
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    item_number,
    customer_number,
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
    2 AS Allocation_Priority,
    
    -- Suppression flag
    Is_Suppressed,
    
    -- FG SOURCE (PAB-style): Carried through from view 06
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from view 06
    Construct
    
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'WFQ'
  AND Can_Allocate = 1
  AND Is_Suppressed = 0

UNION ALL

-- RMQTY Batches (released only)
-- FG/Construct carried through from view 06
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    item_number,
    customer_number,
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
    3 AS Allocation_Priority,
    
    -- Suppression flag
    Is_Suppressed,
    
    -- FG SOURCE (PAB-style): Carried through from view 06
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from view 06
    Construct
    
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'RMQTY'
  AND Can_Allocate = 1
  AND Is_Suppressed = 0;

-- ============================================================================
-- END OF VIEW 07 (CONSOLIDATED FINAL)
-- ============================================================================
