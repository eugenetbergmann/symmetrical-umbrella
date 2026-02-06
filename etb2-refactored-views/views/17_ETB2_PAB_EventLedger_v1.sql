/* VIEW 17 - STATUS: PRODUCTION STABILIZED */
-- ============================================================================
-- VIEW 17: dbo.ETB2_PAB_EventLedger_v1 (PRODUCTION STABILIZED)
-- ============================================================================
-- Purpose: Event ledger combining Purchase Orders and PAB Auto Demand
--          SUPPRESSION-SAFE: Suppressed demand does not erode PAB balance
-- Grain: One row per event (PO line or demand line)
-- Dependencies:
--   - dbo.POP10100, dbo.POP10110 (external tables - PO data)
--   - dbo.ETB_PAB_AUTO (external table - demand data)
--   - dbo.IV00102 (external table - item data)
--   - dbo.Prosenthal_Vendor_Items (external table - vendor item data)
--   - dbo.ETB_ActiveDemand_Union_FG_MO (external table - FG SOURCE)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct derived from ETB_ActiveDemand_Union_FG_MO for demand events
--   - Is_Suppressed flag: Items LIKE 'MO-%' are flagged and demand set to 0
--   - Event_Sort_Priority for deterministic ordering
-- Stabilization:
--   - Suppression Integrity: Demand is only subtracted if it passes suppression filter
--   - Math Correctness: PAB calculation follows Prime Law (Beg Bal + Inflows - Outflows)
--   - Execution Stability: Uses correlated subqueries for deterministic performance
-- Last Updated: 2026-02-06
-- ============================================================================

-- ============================================================================
-- FG SOURCE (FIXED): Pre-calculate FG/Construct from ETB_ActiveDemand_Union_FG_MO
-- FIX: Uses correct source column names from ETB_ActiveDemand_Union_FG_MO
-- Schema Map: Customer->Construct, FG->FG_Item_Number, [FG Desc]->FG_Description
-- ============================================================================
WITH FG_From_MO AS (
    SELECT
        m.MONumber AS ORDERNUMBER,
        -- Enforced Schema Map: FG -> FG_Item_Number
        m.FG AS FG_Item_Number,
        -- Enforced Schema Map: [FG Desc] -> FG_Description
        m.[FG Desc] AS FG_Description,
        -- Enforced Schema Map: Customer -> Construct
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

-- ============================================================================
-- CleanOrder mapping for PAB_AUTO with SUPPRESSION LOGIC
-- ============================================================================
PABWithCleanOrder AS (
    SELECT
        pab.ORDERNUMBER,
        pab.ITEMNMBR,
        pab.DUEDATE,
        pab.Running_Balance,
        pab.STSDESCR,
        pab.DEDUCTIONS,
        pab.MRP_TYPE,
        
        -- SUPPRESSION FLAG: Items LIKE 'MO-%' are suppressed
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
-- EVENT STREAM: All events with proper prioritization
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
        'BEGIN' AS Event_Type,
        NULL AS Order_Number,
        NULL AS Vendor_ID,
        NULL AS Unit_Of_Measure,
        CAST(0 AS DECIMAL(18,4)) AS Ordered_Qty,
        CAST(0 AS DECIMAL(18,4)) AS Received_Qty,
        CAST(0 AS DECIMAL(18,4)) AS Remaining_Qty,
        CAST(0 AS BIT) AS Is_Suppressed,
        NULL AS FG_Item_Number,
        NULL AS FG_Description,
        NULL AS Construct
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
        'PO' AS Event_Type,
        LTRIM(RTRIM(p.PONUMBER)) AS Order_Number,
        LTRIM(RTRIM(p.VENDORID)) AS Vendor_ID,
        pd.UOFM AS Unit_Of_Measure,
        COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) AS Ordered_Qty,
        COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) AS Received_Qty,
        COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) AS Remaining_Qty,
        CAST(0 AS BIT) AS Is_Suppressed,
        NULL AS FG_Item_Number,
        NULL AS FG_Description,
        NULL AS Construct
    FROM dbo.POP10100 p WITH (NOLOCK)
    INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
    WHERE pd.ITEMNMBR IN (
        SELECT Item_Number
        FROM dbo.ETB2_Demand_Cleaned_Base
        WHERE client = 'DEFAULT_CLIENT' AND contract = 'DEFAULT_CONTRACT' AND run = 'CURRENT_RUN'
    )
      AND pd.ITEMNMBR NOT LIKE 'MO-%'
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
        'DEMAND' AS Event_Type,
        LTRIM(RTRIM(pco.ORDERNUMBER)) AS Order_Number,
        '' AS Vendor_ID,
        '' AS Unit_Of_Measure,
        pco.Suppressed_Deductions AS Ordered_Qty,
        CAST(0 AS DECIMAL(18,4)) AS Received_Qty,
        pco.Suppressed_Deductions AS Remaining_Qty,
        CAST(pco.Is_Suppressed AS BIT) AS Is_Suppressed,
        fg.FG_Item_Number,
        fg.FG_Description,
        fg.Construct
    FROM PABWithCleanOrder pco
    LEFT JOIN FG_From_MO fg
        ON pco.CleanOrder = fg.CleanOrder
    WHERE pco.MRP_TYPE = 6  -- Demand type
    
    UNION ALL
    
    -- 4. EXPIRY (Priority 4): ADD (treated as supply inflow)
    SELECT
        pab.ITEMNMBR,
        TRY_CONVERT(DATE, pab.[Date + Expiry]) AS E_Date,
        4 AS E_Pri,
        COALESCE(TRY_CAST(pab.EXPIRY AS DECIMAL(18,4)), 0) AS Delta,
        'EXPIRY' AS Event_Type,
        NULL AS Order_Number,
        '' AS Vendor_ID,
        '' AS Unit_Of_Measure,
        COALESCE(TRY_CAST(pab.EXPIRY AS DECIMAL(18,4)), 0) AS Ordered_Qty,
        CAST(0 AS DECIMAL(18,4)) AS Received_Qty,
        COALESCE(TRY_CAST(pab.EXPIRY AS DECIMAL(18,4)), 0) AS Remaining_Qty,
        CAST(0 AS BIT) AS Is_Suppressed,
        NULL AS FG_Item_Number,
        NULL AS FG_Description,
        NULL AS Construct
    FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
    WHERE pab.MRP_TYPE = 11  -- Expiry type
      AND pab.ITEMNMBR NOT LIKE '60.%'
      AND pab.ITEMNMBR NOT LIKE '70.%'
),

-- ============================================================================
-- LEDGER CALCULATION: Running PAB using correlated subquery
-- No window functions for deterministic performance across legacy SQL environments
-- ============================================================================
LedgerCalculation AS (
    SELECT 
        e1.ITEMNMBR,
        e1.E_Date,
        e1.E_Pri,
        e1.Event_Type,
        e1.Delta,
        e1.Order_Number,
        e1.Vendor_ID,
        e1.Unit_Of_Measure,
        e1.Ordered_Qty,
        e1.Received_Qty,
        e1.Remaining_Qty,
        e1.Is_Suppressed,
        e1.FG_Item_Number,
        e1.FG_Description,
        e1.Construct,
        
        -- Correlated subquery for running balance (deterministic)
        (SELECT SUM(e2.Delta) 
         FROM EventStream e2 
         WHERE e2.ITEMNMBR = e1.ITEMNMBR 
           AND (e2.E_Date < e1.E_Date 
                OR (e2.E_Date = e1.E_Date AND e2.E_Pri <= e1.E_Pri))
        ) AS Running_PAB
        
    FROM EventStream e1
)

-- ============================================================================
-- FINAL OUTPUT: Event Ledger with Running PAB
-- ============================================================================
SELECT
    -- Context columns
    'DEFAULT_CLIENT' AS client,
    'DEFAULT_CONTRACT' AS contract,
    'CURRENT_RUN' AS run,
    
    -- Event identification
    ITEMNMBR AS Item_Number,
    E_Date AS Event_Date,
    E_Pri AS Event_Sort_Priority,
    Event_Type,
    Order_Number,
    Vendor_ID,
    Unit_Of_Measure,
    
    -- Quantities
    Ordered_Qty,
    Received_Qty,
    Remaining_Qty,
    Delta AS Qty_Change,
    
    -- PAB Running Balance
    Running_PAB AS PAB_Balance,
    
    -- Stockout indicator
    CASE WHEN Running_PAB < 0 THEN 1 ELSE 0 END AS Is_Stockout,
    
    -- FG/Construct (for demand events)
    FG_Item_Number,
    FG_Description,
    Construct,
    
    -- Suppression flag
    Is_Suppressed,
    
    -- Metadata
    GETDATE() AS ETB2_Load_Date

FROM LedgerCalculation
WHERE Running_PAB IS NOT NULL  -- Exclude events before BEG BAL

UNION ALL

-- Include PO events that don't have running balance calculated yet
SELECT
    'DEFAULT_CLIENT' AS client,
    'DEFAULT_CONTRACT' AS contract,
    'CURRENT_RUN' AS run,
    
    ITEMNMBR AS Item_Number,
    E_Date AS Event_Date,
    E_Pri AS Event_Sort_Priority,
    Event_Type,
    Order_Number,
    Vendor_ID,
    Unit_Of_Measure,
    
    Ordered_Qty,
    Received_Qty,
    Remaining_Qty,
    Delta AS Qty_Change,
    
    -- No PAB for PO-only items without demand
    NULL AS PAB_Balance,
    
    -- Stockout indicator
    0 AS Is_Stockout,
    
    -- FG/Construct
    FG_Item_Number,
    FG_Description,
    Construct,
    
    -- Suppression flag
    Is_Suppressed,
    
    -- Metadata
    GETDATE() AS ETB2_Load_Date

FROM EventStream e1
WHERE Event_Type = 'PO'
  AND NOT EXISTS (
      SELECT 1 FROM EventStream e2 
      WHERE e2.ITEMNMBR = e1.ITEMNMBR 
        AND e2.Event_Type IN ('BEGIN', 'DEMAND')
  );

-- ============================================================================
-- END OF VIEW 17 (PRODUCTION STABILIZED)
-- ============================================================================
