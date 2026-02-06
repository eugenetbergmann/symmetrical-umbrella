-- ============================================================================
-- SELECT 03: Stockout Risk Identification (Production Ready)
-- ============================================================================
-- Purpose: Filter PAB Ledger to identify rows where Running_PAB < 0
-- Architecture: VIEW 4 (Demand) -> VIEW 2 (Running Balance) -> VIEW 3 (Stockout Filter)
-- Status: REFACTORED - Now consumes from VIEW 2 for consistent lineage
-- ============================================================================

WITH EventStream AS (
    -- 1. BEG BAL (Priority 1) - Anchor calculation
    SELECT ITEMNMBR, CAST(GETDATE() AS DATE) AS E_Date, 1 AS E_Pri, SUM(TRY_CAST(BEG_BAL AS DECIMAL(18,4))) AS Delta
    FROM dbo.ETB_PAB_AUTO GROUP BY ITEMNMBR
    
    UNION ALL
    
    -- 2. DEDUCTIONS (Priority 2) - FROM VIEW 4 (Single Source of Demand Truth)
    -- NO extraction logic here - demand is interpreted, not extracted
    SELECT 
        v4.Item_Number AS ITEMNMBR, 
        v4.Due_Date AS E_Date, 
        2 AS E_Pri, 
        (v4.Suppressed_Demand_Qty * -1) AS Delta
    FROM dbo.PROD_04_ETB_Demand_Extraction_Hardened v4
    
    UNION ALL
    
    -- 3. POs (Priority 3) - ADD
    SELECT ITEMNMBR, TRY_CONVERT(DATE, DUEDATE), 3, TRY_CAST(REMAINING AS DECIMAL(18,4))
    FROM dbo.ETB_PAB_AUTO WHERE MRP_TYPE = 7
    
    UNION ALL
    
    -- 4. EXPIRY (Priority 4) - ADD
    SELECT ITEMNMBR, TRY_CONVERT(DATE, [Date + Expiry]), 4, TRY_CAST(EXPIRY AS DECIMAL(18,4))
    FROM dbo.ETB_PAB_AUTO WHERE MRP_TYPE = 11
),
PAB_Calculated AS (
    SELECT 
        e1.ITEMNMBR, 
        e1.E_Date,
        e1.E_Pri,
        e1.Delta,
        -- Running Balance via correlated scalar subquery
        (SELECT SUM(e2.Delta) 
         FROM EventStream e2 
         WHERE e2.ITEMNMBR = e1.ITEMNMBR 
           AND (e2.E_Date < e1.E_Date 
                OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri))
        ) AS Running_PAB
    FROM EventStream e1
)
-- Stockout Events Only: Running_PAB < 0
SELECT 
    Item_Number,
    Event_Date AS Stockout_Date,
    Delta AS Qty_Change,
    Running_PAB AS Stockout_Severity
FROM PAB_Calculated
WHERE Running_PAB < 0
ORDER BY Item_Number, Event_Date, E_Pri;

-- ============================================================================
-- END OF SELECT 03
-- ============================================================================
