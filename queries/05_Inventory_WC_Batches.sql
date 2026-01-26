/*******************************************************************************
* View Name:    ETB2_Inventory_WC_Batches
* Deploy Order: 05 of 17
* 
* Purpose:      Work center inventory batches with FEFO ordering and expiry dates
* Grain:        One row per item per work center per batch
* 
* Dependencies:
*   ✓ dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (inventory - external table)
*   ✓ dbo.EXT_BINTYPE (bin types - external table)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Inventory_WC_Batches
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Inventory_WC_Batches
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    i.ITEMNMBR,
    i.LOCNID AS Work_Center,
    i.BIN AS Batch_Number,
    i.QTY AS Quantity,
    i.EXTDATE AS Expiry_Date,
    DATEDIFF(DAY, GETDATE(), i.EXTDATE) AS Days_To_Expiry,  -- Positive = future expiry
    -- FEFO rank: oldest expiry first (1 = expiring soonest)
    CASE 
        WHEN e.FEFO_FLAG = 1 
        THEN ROW_NUMBER() OVER (PARTITION BY i.ITEMNMBR, i.LOCNID ORDER BY i.EXTDATE ASC)
        ELSE 0 
    END AS FEFO_Rank,
    i.QTYTYPE AS Quantity_Type_Code,
    e.FEFO_FLAG AS Is_FEFO_Enabled
FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE i
LEFT JOIN dbo.EXT_BINTYPE e ON i.QTYTYPE = e.BINTYPE
WHERE i.QTY > 0  -- Only positive quantities
    AND i.LOCNCODE LIKE 'WC[_-]%'  -- Work center locations only

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
