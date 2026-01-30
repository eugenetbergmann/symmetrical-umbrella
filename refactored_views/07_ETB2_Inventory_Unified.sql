-- ============================================================================
-- VIEW 07: dbo.ETB2_Inventory_Unified (NEW)
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT...UNION...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Inventory_Unified
-- ============================================================================
-- Purpose: All eligible inventory consolidated (WC + released holds)
-- Grain: Item/Lot
-- Dependencies:
--   - dbo.ETB2_Inventory_WC_Batches (view 05)
--   - dbo.ETB2_Inventory_Quarantine_Restricted (view 06)
-- Last Updated: 2026-01-30
-- ============================================================================

-- WC Batches (always eligible)
-- FG/Construct carried through from view 05
SELECT
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
    -- FG SOURCE (PAB-style): Carried through from view 05
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from view 05
    Construct
FROM dbo.ETB2_Inventory_WC_Batches WITH (NOLOCK)

UNION ALL

-- WFQ Batches (released only)
-- FG/Construct carried through from view 06
SELECT
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
    -- FG SOURCE (PAB-style): Carried through from view 06
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from view 06
    Construct
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'WFQ'
  AND Can_Allocate = 1

UNION ALL

-- RMQTY Batches (released only)
-- FG/Construct carried through from view 06
SELECT
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
    -- FG SOURCE (PAB-style): Carried through from view 06
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from view 06
    Construct
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'RMQTY'
  AND Can_Allocate = 1;

-- ============================================================================
-- END OF VIEW 07
-- ============================================================================
