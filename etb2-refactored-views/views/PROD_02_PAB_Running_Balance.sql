-- ============================================================================
-- SELECT 02: Stabilized PAB Ledger - Running Balance (Production Ready)
-- ============================================================================
-- Purpose: Projected Available Balance ledger with deterministic running total
--          THIN ORCHESTRATION LAYER - Calls VIEW 4 for demand truth
-- Architecture: VIEW 4 (Demand Extraction) -> VIEW 2 (Planning/Modeling)
-- Math: Scalar subquery for running balance (no window functions)
-- Status: REFACTORED - Now consumes from single demand source (VIEW 4)
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
        TRY_CONVERT(DATE, DUEDATE),
        3,
        TRY_CAST(REMAINING AS DECIMAL(18,4)),
        'PO'
    FROM dbo.ETB_PAB_AUTO
    WHERE MRPTYPE = 7


    UNION ALL


    ------------------------------------------------
    -- EXPIRY RETURNS
    ------------------------------------------------
    SELECT
        ITEMNMBR,
        TRY_CONVERT(DATE, [Date + Expiry]),
        4,
        TRY_CAST(EXPIRY AS DECIMAL(18,4)),
        'EXPIRY'
    FROM dbo.ETB_PAB_AUTO
    WHERE MRPTYPE = 11
),

LedgerCalculation AS (

    SELECT 
        e1.ITEMNMBR, 
        e1.E_Date, 
        e1.E_Pri,
        e1.Type, 
        e1.Delta,

        (
            SELECT SUM(e2.Delta)
            FROM EventStream e2
            WHERE e2.ITEMNMBR = e1.ITEMNMBR
              AND (
                    e2.E_Date < e1.E_Date
                 OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri)
              )
        ) AS Running_PAB

    FROM EventStream e1
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
