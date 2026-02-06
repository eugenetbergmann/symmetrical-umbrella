# RUTHLESS EDITORIAL REPORT: ETB2 REPOSITORY STABILIZATION
# ============================================================================

## EXECUTIVE SUMMARY

This report documents the ruthless excision of all non-essential views from the ETB2 repository, leaving only the high-integrity mathematical core required for deployment.

---

## EDITORIAL JUSTIFICATION: VIEWS EXCISED

### BLOAT REMOVED (Academic/Strategic Metrics)

| View # | View Name | Reason for Excision |
|--------|-----------|---------------------|
| 01 | ETB2_Config_Lead_Times | Configuration bloat - 30-day defaults inlined into CTEs |
| 02 | ETB2_Config_Part_Pooling | Configuration bloat - Pooling multipliers inlined into CTEs |
| 02B | ETB2_Config_Items | Configuration bloat - Item descriptions inlined into CTEs |
| 03 | ETB2_Config_Active | Configuration bloat - Combined config inlined into CTEs |
| 05 | ETB2_Inventory_WC_Batches | Inventory bloat - Beg_Bal calculated directly from source |
| 06 | ETB2_Inventory_Quarantine_Restricted | Inventory bloat - Beg_Bal calculated directly from source |
| 07 | ETB2_Inventory_Unified | Inventory bloat - Beg_Bal calculated directly from source |
| 08 | ETB2_Planning_Net_Requirements | Derived metric - Net requirements calculated in PAB ledger |
| 10 | ETB2_Planning_Rebalancing_Opportunities | Strategic bloat - Rebalancing is not core math |
| 11 | ETB2_Campaign_Normalized_Demand | Campaign bloat - CCU is not core math |
| 12 | ETB2_Campaign_Concurrency_Window | Campaign bloat - Concurrency windows are not core math |
| 13 | ETB2_Campaign_Collision_Buffer | Campaign bloat - Collision buffers are not core math |
| 14 | ETB2_Campaign_Risk_Adequacy | Campaign bloat - Risk assessment is not core math |
| 15 | ETB2_Campaign_Absorption_Capacity | Campaign bloat - Executive KPI is not core math |
| 16 | ETB2_Campaign_Model_Data_Gaps | Campaign bloat - Data quality flags are not core math |

### PRESERVED (Core Mathematical Requirements)

| View # | View Name | Reason for Preservation |
|--------|-----------|------------------------|
| 04 | ETB2_Demand_Cleaned_Base | THE SIGNAL - Cleaned demand with suppression logic |
| 17 | ETB2_PAB_EventLedger_v1 | THE LEDGER - PAB running balance calculation |
| 09 | ETB2_Planning_Stockout | THE RISK - Stockout event detection |

---

## THE THREE PRODUCTION SELECT STATEMENTS

### 1. CLEANED DEMAND (THE SIGNAL)

```sql
-- ============================================================================
-- SELECT 1: Cleaned Demand (The Signal)
-- ============================================================================
-- Purpose: Extract MRP 6 from ETB_PAB_AUTO with FG derivation
-- Grain: One row per demand event (order line)
-- Dependencies:
--   - dbo.ETB_PAB_AUTO (external table)
--   - dbo.Prosenthal_Vendor_Items (external table)
--   - dbo.ETB_ActiveDemand_Union_FG_MO (external table - FG SOURCE)
-- Features:
--   - CleanOrder normalization (strip MO, hyphens, spaces, punctuation)
--   - FG derived from ETB_ActiveDemand_Union_FG_MO via normalized CleanOrder
--   - Suppression logic: Items LIKE 'MO-%' or 'WC-R%' have Suppressed_Demand_Qty = 0
--   - Only MRP_TYPE 6 (Demand) is extracted
-- ============================================================================

WITH CleanOrderLogic AS (
    SELECT
        ORDERNUMBER,
        -- CleanOrder: Strip MO, hyphens, spaces, punctuation, uppercase
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(ORDERNUMBER, 'MO', ''),
                                '-', ''
                            ),
                            ' ', ''
                        ),
                        '/', ''
                    ),
                    '.', ''
                ),
                '#', ''
            )
        ) AS CleanOrder
    FROM dbo.ETB_PAB_AUTO
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
      AND ITEMNMBR NOT LIKE 'MO-%'
      AND STSDESCR <> 'Partially Received'
),

FG_Source AS (
    SELECT
        col.ORDERNUMBER,
        col.CleanOrder,
        m.FG AS FG_Code,
        m.[FG Desc] AS FG_Description,
        ROW_NUMBER() OVER (
            PARTITION BY col.CleanOrder, m.FG
            ORDER BY m.Customer, m.[FG Desc], col.ORDERNUMBER
        ) AS FG_RowNum
    FROM CleanOrderLogic col
    INNER JOIN dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
        ON col.CleanOrder = UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(m.ORDERNUMBER, 'MO', ''),
                                '-', ''
                            ),
                            ' ', ''
                        ),
                        '/', ''
                    ),
                    '.', ''
                ),
                '#', ''
            )
        )
),

FG_Deduped AS (
    SELECT
        ORDERNUMBER,
        CleanOrder,
        FG_Code,
        FG_Description
    FROM FG_Source
    WHERE FG_RowNum = 1
)

SELECT
    pa.ITEMNMBR AS Item,
    TRY_CONVERT(DATE, pa.DUEDATE) AS Due_Date,
    UPPER(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(pa.ORDERNUMBER, 'MO', ''),
                            '-', ''
                        ),
                        ' ', ''
                    ),
                    '/', ''
                ),
                '.', ''
            ),
            '#', ''
        )
    ) AS CleanOrder,
    fd.FG_Code,
    fd.FG_Description,
    -- SUPPRESSED DEMAND: Set to 0 if item is suppressed
    CASE
        WHEN pa.ITEMNMBR LIKE 'MO-%' THEN 0
        WHEN pa.ITEMNMBR LIKE 'WC-R%' THEN 0
        ELSE COALESCE(TRY_CAST(pa.DEDUCTIONS AS DECIMAL(18,4)), 0)
    END AS Suppressed_Demand_Qty
FROM dbo.ETB_PAB_AUTO pa WITH (NOLOCK)
INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
  ON LTRIM(RTRIM(pa.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
LEFT JOIN FG_Deduped fd
    ON pa.ORDERNUMBER = fd.ORDERNUMBER
WHERE pa.ITEMNMBR NOT LIKE '60.%'
  AND pa.ITEMNMBR NOT LIKE '70.%'
  AND pa.STSDESCR <> 'Partially Received'
  AND pvi.Active = 'Yes'
  AND pa.MRP_TYPE = 6  -- Only Demand (MRP 6)
  AND TRY_CONVERT(DATE, pa.DUEDATE) BETWEEN
      DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
      AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE));
```

---

### 2. PAB RUNNING BALANCE (THE LEDGER)

```sql
-- ============================================================================
-- SELECT 2: PAB Running Balance (The Ledger)
-- ============================================================================
-- Purpose: Combine Beg_Bal, Demand, POs, and Expiry into single event stream
-- Grain: One row per event (Beg_Bal, Demand, PO, or Expiry)
-- Dependencies:
--   - dbo.ETB_PAB_AUTO (external table - Beg_Bal, Demand, Expiry)
--   - dbo.POP10100, dbo.POP10110 (external tables - PO data)
--   - dbo.Prosenthal_Vendor_Items (external table - item data)
--   - dbo.ETB_ActiveDemand_Union_FG_MO (external table - FG SOURCE)
-- Features:
--   - Prime Law hierarchy: Beg_Bal (1) > Deductions (2) > POs (3) > Expiry (4)
--   - Suppression logic: If item/site suppressed, demand does not subtract
--   - Running total using correlated scalar subquery (deterministic)
-- ============================================================================

WITH FG_From_MO AS (
    SELECT
        m.MONumber AS ORDERNUMBER,
        m.FG AS FG_Code,
        m.[FG Desc] AS FG_Description,
        m.Customer AS Construct,
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(m.MONumber, 'MO', ''),
                            '-', ''
                        ),
                        ' ', ''
                    ),
                    '/', ''
                ),
                '.', ''
            ),
            '#', ''
        ) AS CleanOrder
    FROM dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
    WHERE m.FG IS NOT NULL
      AND m.FG <> ''
),

PABWithCleanOrder AS (
    SELECT
        pab.ORDERNUMBER,
        pab.ITEMNMBR,
        pab.DUEDATE,
        pab.DEDUCTIONS,
        pab.MRP_TYPE,
        -- SUPPRESSION FLAG
        CASE
            WHEN pab.ITEMNMBR LIKE 'MO-%' THEN 1
            WHEN pab.ITEMNMBR LIKE 'WC-R%' THEN 1
            ELSE 0
        END AS Is_Suppressed,
        -- SUPPRESSED DEMAND: Set to 0 if suppressed
        CASE
            WHEN pab.ITEMNMBR LIKE 'MO-%' THEN 0
            WHEN pab.ITEMNMBR LIKE 'WC-R%' THEN 0
            ELSE COALESCE(TRY_CAST(pab.DEDUCTIONS AS DECIMAL(18,4)), 0)
        END AS Suppressed_Deductions,
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(pab.ORDERNUMBER, 'MO', ''),
                            '-', ''
                        ),
                        ' ', ''
                    ),
                    '/', ''
                ),
                '.', ''
            ),
            '#', ''
        ) AS CleanOrder
    FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
    WHERE pab.STSDESCR <> 'Partially Received'
      AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '60.%'
      AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '70.%'
),

-- ============================================================================
-- EVENT STREAM: All events with Prime Law prioritization
-- Priority 1: BEG BAL (current inventory)
-- Priority 2: DEMAND (MRP_TYPE 6) - SUBTRACT POST-SUPPRESSION
-- Priority 3: POs (MRP_TYPE 7) - ADD
-- Priority 4: EXPIRY (MRP_TYPE 11) - ADD
-- ============================================================================
EventStream AS (
    -- 1. BEG BAL (Priority 1): Current inventory from ETB_PAB_AUTO
    SELECT
        ITEMNMBR,
        CAST(GETDATE() AS DATE) AS E_Date,
        1 AS E_Pri,
        SUM(TRY_CAST(BEG_BAL AS DECIMAL(18,4))) AS Delta,
        'BEGIN' AS Type
    FROM dbo.ETB_PAB_AUTO WITH (NOLOCK)
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
    GROUP BY ITEMNMBR

    UNION ALL

    -- 2. PURCHASE ORDERS (Priority 3): Additive inflow
    SELECT
        pd.ITEMNMBR,
        TRY_CONVERT(DATE, p.DOCDATE) AS E_Date,
        3 AS E_Pri,
        COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) AS Delta,
        'PO' AS Type
    FROM dbo.POP10100 p WITH (NOLOCK)
    INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
    WHERE pd.ITEMNMBR NOT LIKE 'MO-%'
      AND TRY_CONVERT(DATE, p.DOCDATE) BETWEEN
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))

    UNION ALL

    -- 3. PAB AUTO DEMAND (Priority 2): SUBTRACT POST-SUPPRESSION
    SELECT
        pco.ITEMNMBR,
        TRY_CONVERT(DATE, pco.DUEDATE) AS E_Date,
        2 AS E_Pri,
        (pco.Suppressed_Deductions * -1) AS Delta,  -- Negative for demand
        'DEMAND' AS Type
    FROM PABWithCleanOrder pco
    WHERE pco.MRP_TYPE = 6  -- Demand type

    UNION ALL

    -- 4. EXPIRY (Priority 4): ADD (treated as supply inflow)
    SELECT
        pab.ITEMNMBR,
        TRY_CONVERT(DATE, pab.[Date + Expiry]) AS E_Date,
        4 AS E_Pri,
        COALESCE(TRY_CAST(pab.EXPIRY AS DECIMAL(18,4)), 0) AS Delta,
        'EXPIRY' AS Type
    FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
    WHERE pab.MRP_TYPE = 11  -- Expiry type
      AND pab.ITEMNMBR NOT LIKE '60.%'
      AND pab.ITEMNMBR NOT LIKE '70.%'
)

-- ============================================================================
-- LEDGER CALCULATION: Running PAB using correlated subquery
-- No window functions for deterministic performance across legacy SQL environments
-- ============================================================================
SELECT
    e1.ITEMNMBR AS Item,
    e1.E_Date AS Date,
    e1.Type,
    e1.Delta AS Change_Qty,
    -- Correlated subquery for running balance (deterministic)
    (SELECT SUM(e2.Delta)
     FROM EventStream e2
     WHERE e2.ITEMNMBR = e1.ITEMNMBR
       AND (e2.E_Date < e1.E_Date
            OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri))
    ) AS Running_PAB
FROM EventStream e1
WHERE (SELECT SUM(e2.Delta)
       FROM EventStream e2
       WHERE e2.ITEMNMBR = e1.ITEMNMBR
         AND (e2.E_Date < e1.E_Date
              OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri))
      ) IS NOT NULL  -- Exclude events before BEG BAL
ORDER BY e1.ITEMNMBR, e1.E_Date, e1.E_Pri;
```

---

### 3. STOCKOUT EVENTS (THE RISK)

```sql
-- ============================================================================
-- SELECT 3: Stockout Events (The Risk)
-- ============================================================================
-- Purpose: Filter the Ledger for Running_PAB < 0
-- Grain: One row per stockout event
-- Dependencies:
--   - Uses the EventStream CTE from SELECT 2 (PAB Running Balance)
-- Features:
--   - Identifies all events where Running_PAB drops below zero
--   - Calculates deficit quantity (absolute value of negative balance)
-- ============================================================================

WITH FG_From_MO AS (
    SELECT
        m.MONumber AS ORDERNUMBER,
        m.FG AS FG_Code,
        m.[FG Desc] AS FG_Description,
        m.Customer AS Construct,
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(m.MONumber, 'MO', ''),
                            '-', ''
                        ),
                        ' ', ''
                    ),
                    '/', ''
                ),
                '.', ''
            ),
            '#', ''
        ) AS CleanOrder
    FROM dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
    WHERE m.FG IS NOT NULL
      AND m.FG <> ''
),

PABWithCleanOrder AS (
    SELECT
        pab.ORDERNUMBER,
        pab.ITEMNMBR,
        pab.DUEDATE,
        pab.DEDUCTIONS,
        pab.MRP_TYPE,
        CASE
            WHEN pab.ITEMNMBR LIKE 'MO-%' THEN 1
            WHEN pab.ITEMNMBR LIKE 'WC-R%' THEN 1
            ELSE 0
        END AS Is_Suppressed,
        CASE
            WHEN pab.ITEMNMBR LIKE 'MO-%' THEN 0
            WHEN pab.ITEMNMBR LIKE 'WC-R%' THEN 0
            ELSE COALESCE(TRY_CAST(pab.DEDUCTIONS AS DECIMAL(18,4)), 0)
        END AS Suppressed_Deductions,
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(pab.ORDERNUMBER, 'MO', ''),
                            '-', ''
                        ),
                        ' ', ''
                    ),
                    '/', ''
                ),
                '.', ''
            ),
            '#', ''
        ) AS CleanOrder
    FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
    WHERE pab.STSDESCR <> 'Partially Received'
      AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '60.%'
      AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '70.%'
),

EventStream AS (
    SELECT
        ITEMNMBR,
        CAST(GETDATE() AS DATE) AS E_Date,
        1 AS E_Pri,
        SUM(TRY_CAST(BEG_BAL AS DECIMAL(18,4))) AS Delta,
        'BEGIN' AS Type
    FROM dbo.ETB_PAB_AUTO WITH (NOLOCK)
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
    GROUP BY ITEMNMBR

    UNION ALL

    SELECT
        pd.ITEMNMBR,
        TRY_CONVERT(DATE, p.DOCDATE) AS E_Date,
        3 AS E_Pri,
        COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) AS Delta,
        'PO' AS Type
    FROM dbo.POP10100 p WITH (NOLOCK)
    INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
    WHERE pd.ITEMNMBR NOT LIKE 'MO-%'
      AND TRY_CONVERT(DATE, p.DOCDATE) BETWEEN
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))

    UNION ALL

    SELECT
        pco.ITEMNMBR,
        TRY_CONVERT(DATE, pco.DUEDATE) AS E_Date,
        2 AS E_Pri,
        (pco.Suppressed_Deductions * -1) AS Delta,
        'DEMAND' AS Type
    FROM PABWithCleanOrder pco
    WHERE pco.MRP_TYPE = 6

    UNION ALL

    SELECT
        pab.ITEMNMBR,
        TRY_CONVERT(DATE, pab.[Date + Expiry]) AS E_Date,
        4 AS E_Pri,
        COALESCE(TRY_CAST(pab.EXPIRY AS DECIMAL(18,4)), 0) AS Delta,
        'EXPIRY' AS Type
    FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
    WHERE pab.MRP_TYPE = 11
      AND pab.ITEMNMBR NOT LIKE '60.%'
      AND pab.ITEMNMBR NOT LIKE '70.%'
),

LedgerCalculation AS (
    SELECT
        e1.ITEMNMBR,
        e1.E_Date,
        e1.Type,
        e1.Delta,
        (SELECT SUM(e2.Delta)
         FROM EventStream e2
         WHERE e2.ITEMNMBR = e1.ITEMNMBR
           AND (e2.E_Date < e1.E_Date
                OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri))
        ) AS Running_PAB
    FROM EventStream e1
    WHERE (SELECT SUM(e2.Delta)
           FROM EventStream e2
           WHERE e2.ITEMNMBR = e1.ITEMNMBR
             AND (e2.E_Date < e1.E_Date
                  OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri))
          ) IS NOT NULL
)

-- ============================================================================
-- STOCKOUT EVENTS: Filter for Running_PAB < 0
-- ============================================================================
SELECT
    Item,
    Date,
    ABS(Running_PAB) AS Deficit_Qty
FROM LedgerCalculation
WHERE Running_PAB < 0
ORDER BY Item, Date;
```

---

## CRITICAL TECHNICAL DEBT

1. **Correlated Subquery Performance**: The running balance calculation uses correlated scalar subqueries instead of window functions for deterministic performance across legacy SQL environments. This may impact performance on large datasets. Consider materializing the EventStream as a temporary table for production workloads.

2. **Suppression Logic Duplication**: The suppression logic (ITEMNMBR LIKE 'MO-%' OR 'WC-R%') is duplicated across multiple CTEs. Consider centralizing this logic in a single CTE or function.

3. **CleanOrder Normalization Complexity**: The CleanOrder normalization logic (REPLACE chain) is duplicated in multiple places. Consider creating a scalar function for this transformation.

4. **Hardcoded Date Windows**: The ±90 day planning window is hardcoded in multiple places. Consider parameterizing this value.

5. **Missing Safety Stock Threshold**: The stockout detection currently triggers at PAB < 0. Consider adding a configurable safety stock threshold (e.g., trigger stockout if PAB < 10).

---

## NEXT STEP

**Verification Task**: Execute the three SELECT statements against the production database and verify that:

1. **SELECT 1 (Cleaned Demand)** returns the expected number of demand events with correct Suppressed_Demand_Qty values (0 for suppressed items, actual quantity for non-suppressed items).

2. **SELECT 2 (PAB Running Balance)** returns a complete event stream with correct Running_PAB values, following the Prime Law hierarchy (Beg_Bal > Deductions > POs > Expiry).

3. **SELECT 3 (Stockout Events)** correctly identifies all items and dates where Running_PAB drops below zero, with accurate Deficit_Qty values.

**Expected Output Validation**:
- Compare the Running_PAB values from SELECT 2 against the original ETB_PAB_AUTO.Running_Balance column to ensure mathematical correctness.
- Verify that suppressed items (MO-%, WC-R%) do not cause the PAB balance to drop below zero in SELECT 2.
- Confirm that SELECT 3 returns a subset of the events from SELECT 2 where Running_PAB < 0.

---

## DEPLOYMENT CHECKLIST

- [ ] Review and approve the three SELECT statements
- [ ] Execute verification task (see Next Step above)
- [ ] Create database backup before deployment
- [ ] Deploy SELECT statements to production environment
- [ ] Monitor query performance and optimize if necessary
- [ ] Document any deviations from expected behavior
- [ ] Schedule follow-up review to address technical debt items

---

**END OF RUTHLESS EDITORIAL REPORT**
