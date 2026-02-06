-- ============================================================================
-- SELECT 03: Stockout Risk Identification (Production Ready)
-- ============================================================================
-- Purpose: Filter PAB Ledger to identify rows where Running_PAB < 0
-- Status: DEPLOYED - Production Stabilization Complete
-- ============================================================================

WITH EventStream AS (
    -- 1. BEG BAL (Priority 1) - Anchor calculation
    SELECT ITEMNMBR, CAST(GETDATE() AS DATE) AS E_Date, 1 AS E_Pri, SUM(TRY_CAST(BEG_BAL AS DECIMAL(18,4))) AS Delta
    FROM dbo.ETB_PAB_AUTO GROUP BY ITEMNMBR
    
    UNION ALL
    
    -- 2. DEDUCTIONS (Priority 2) - SUBTRACT POST-SUPPRESSION
    SELECT ITEMNMBR, TRY_CONVERT(DATE, DUEDATE), 2, 
           (CASE WHEN ITEMNMBR LIKE 'MO-%' THEN 0 ELSE TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)) END * -1)
    FROM dbo.ETB_PAB_AUTO WHERE MRP_TYPE = 6
    
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
    Running_PAB AS Deficit_Qty,
    -- Stockout severity classification
    CASE
        WHEN Running_PAB < -1000 THEN 'CRITICAL'
        WHEN Running_PAB < -100 THEN 'HIGH'
        WHEN Running_PAB < -10 THEN 'MEDIUM'
        WHEN Running_PAB < 0 THEN 'LOW'
        ELSE 'NONE'
    END AS Stockout_Severity,
    -- Days until stockout from today
    DATEDIFF(DAY, CAST(GETDATE() AS DATE), Event_Date) AS Days_Until_Stockout
FROM PAB_Calculated
WHERE Running_PAB < 0
ORDER BY ABS(Running_PAB) DESC, Event_Date ASC;

-- ============================================================================
-- END OF SELECT 03
-- ============================================================================
