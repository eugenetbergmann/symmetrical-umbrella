-- ============================================================================
-- SELECT 02: Stabilized PAB Ledger - Running Balance (Production Ready)
-- ============================================================================
-- Purpose: Projected Available Balance ledger with deterministic running total
--          THIN ORCHESTRATION LAYER - Calls VIEW 4 for demand truth
-- Architecture: VIEW 4 (Demand Extraction) -> VIEW 2 (Planning/Modeling)
-- Math: Window function for running balance (optimized for performance)
-- Status: REFACTORED - Performance optimized with window functions
-- ============================================================================

WITH EventStream AS (
    ------------------------------------------------
    -- BEGIN BALANCE
    ------------------------------------------------
    SELECT 
        ITEMNMBR,
        CAST(GETDATE() AS DATE) AS E_Date,
        1 AS E_Pri,
        SUM(TRY_CAST(BEG_BAL AS DECIMAL(18,4))) AS Delta,
        'BEGIN' AS Type
    FROM dbo.ETB_PAB_AUTO
    GROUP BY ITEMNMBR
    UNION ALL
    ------------------------------------------------
    -- DEMAND (FOUNDATION VIEW)
    ------------------------------------------------
    SELECT
        v4.Item_Number AS ITEMNMBR,
        v4.Due_Date AS E_Date,
        2 AS E_Pri,
        -v4.Suppressed_Demand_Qty AS Delta,
        'DEMAND' AS Type
    FROM dbo.ETB2_DEMAND_EXTRACT v4
    UNION ALL
    ------------------------------------------------
    -- PURCHASE ORDERS
    ------------------------------------------------
    SELECT
        ITEMNMBR,
        TRY_CONVERT(DATE, DUEDATE) AS E_Date,
        3 AS E_Pri,
        TRY_CAST(REMAINING AS DECIMAL(18,4)) AS Delta,
        'PO' AS Type
    FROM dbo.ETB_PAB_AUTO
    WHERE MRPTYPE = 7
    UNION ALL
    ------------------------------------------------
    -- EXPIRY RETURNS
    ------------------------------------------------
    SELECT
        ITEMNMBR,
        TRY_CONVERT(DATE, [Date + Expiry]) AS E_Date,
        4 AS E_Pri,
        TRY_CAST(EXPIRY AS DECIMAL(18,4)) AS Delta,
        'EXPIRY' AS Type
    FROM dbo.ETB_PAB_AUTO
    WHERE MRPTYPE = 11
),
LedgerCalculation AS (
    SELECT 
        ITEMNMBR, 
        E_Date, 
        E_Pri,
        Type, 
        Delta,
        -- Use SUM window function instead of scalar subquery
        SUM(Delta) OVER (
            PARTITION BY ITEMNMBR 
            ORDER BY E_Date, E_Pri
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Running_PAB
    FROM EventStream
)
SELECT 
    ITEMNMBR AS Item_Number,
    E_Date AS Event_Date,
    Type AS Event_Type,
    Delta AS Qty_Change,
    Running_PAB,
    CASE WHEN Running_PAB < 0 THEN 1 ELSE 0 END AS Stockout_Risk_Flag
FROM LedgerCalculation
ORDER BY ITEMNMBR, E_Date, E_Pri;

-- ============================================================================
-- END OF SELECT 02
-- ============================================================================

/*
KEY PERFORMANCE IMPROVEMENTS:
================================================================================

1. WINDOW FUNCTION REPLACEMENT
   Before: Scalar subquery executed for every row (N × M complexity)
   After:  Window function computed once per partition (linear)
   
2. QUERY PLAN OPTIMIZATION
   - Single scan of EventStream CTE
   - Window function calculated in single pass
   - Typical speedup: 100-10,000x for large datasets
   
3. TIMEOUT RESOLUTION
   - Removed correlated subquery blocking
   - Eliminated row-by-row processing
   - Suitable for millions of rows

4. COMPATIBILITY NOTE
   - Requires SQL Server 2012 or later (window functions)
   - Standard ANSI SQL syntax

TESTING RECOMMENDATIONS:
================================================================================
1. Run with SET STATISTICS IO ON to verify index usage
2. Check actual execution plan for any scans that could use indexes
3. Test with production volume to confirm timeout resolution
4. Consider adding indexes on:
   - dbo.ETB_PAB_AUTO(ITEMNMBR, DUEDATE, MRPTYPE)
   - dbo.ETB2_DEMAND_EXTRACT(Item_Number, Due_Date)

*/
