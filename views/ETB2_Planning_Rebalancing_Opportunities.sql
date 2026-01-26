-- ============================================================================
-- ETB2 Query: Planning_Rebalancing_Opportunities
-- Purpose: Expiry-driven inventory transfer recommendations
-- Grain: Batch-to-Item Opportunity
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Dependencies: None (fully self-contained)
-- Last Updated: 2026-01-25
-- ============================================================================

WITH

-- Configuration defaults
Config AS (
    SELECT
        90 AS Expiry_Rebalance_Threshold_Days,   -- Batches <=90 days to expiry
        90 AS Forward_Demand_Horizon_Days        -- Demand look-ahead for unmet
),

-- Eligible inventory snapshot (inline T-005 logic, all types eligible)
EligibleInventory AS (
    -- WC Batches
    SELECT
        pib.ITEMNMBR AS Item_Number,
        CONCAT('WC-', pib.LOCNCODE, '-', pib.BIN, '-', pib.ITEMNMBR, '-', CONVERT(VARCHAR(10), CAST(pib.DATERECD AS DATE), 120)) AS Batch_ID,
        pib.LOCNCODE AS Source_Location,
        'WC_BATCH' AS Inventory_Type,
        pib.QTY_Available AS Remaining_Quantity,
        CAST(pib.DATERECD AS DATE) AS Receipt_Date,
        COALESCE(TRY_CONVERT(DATE, pib.EXPNDATE),
                 DATEADD(DAY, 180, CAST(pib.DATERECD AS DATE))) AS Expiry_Date,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE),
                 COALESCE(TRY_CONVERT(DATE, pib.EXPNDATE),
                          DATEADD(DAY, 180, CAST(pib.DATERECD AS DATE)))) AS Days_Until_Expiry
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib
    WHERE pib.LOCNCODE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
    
    UNION ALL
    
    -- Eligible WFQ/RMQTY (hold elapsed)
    SELECT
        iv3.ITEMNMBR AS Item_Number,
        CONCAT(sl.Site_Type, '-', iv3.LOCNCODE, '-', iv3.RCTSEQNM, '-', CONVERT(VARCHAR(10), MAX(CAST(iv3.DATERECD AS DATE)), 120)) AS Batch_ID,
        iv3.LOCNCODE AS Source_Location,
        CASE sl.Site_Type WHEN 'WFQ' THEN 'WFQ_BATCH' ELSE 'RMQTY_BATCH' END AS Inventory_Type,
        SUM(CASE sl.Site_Type
                WHEN 'WFQ'   THEN COALESCE(iv3.ATYALLOC, 0)
                WHEN 'RMQTY' THEN COALESCE(iv3.QTY_RM_I, 0)
            END) AS Remaining_Quantity,
        MAX(CAST(iv3.DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, iv3.EXPNDATE)) AS Expiry_Date,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE), MAX(TRY_CONVERT(DATE, iv3.EXPNDATE))) AS Days_Until_Expiry
    FROM dbo.IV00300 iv3
    INNER JOIN dbo.IV00101 iv1 ON iv3.ITEMNMBR = iv1.ITEMNMBR
    INNER JOIN (SELECT LOCNCODE, Site_Type FROM (VALUES
        ('WFQ-CA01', 'WFQ'), ('WFQ-NY01', 'WFQ'),
        ('RMQTY-CA01', 'RMQTY'), ('RMQTY-NY01', 'RMQTY')
        -- Expand with real locations
    ) AS s(LOCNCODE, Site_Type)) sl ON iv3.LOCNCODE = sl.LOCNCODE
    GROUP BY iv3.ITEMNMBR, iv3.LOCNCODE, iv3.RCTSEQNM, sl.Site_Type
    HAVING
        SUM(CASE sl.Site_Type
                WHEN 'WFQ'   THEN COALESCE(iv3.ATYALLOC, 0)
                WHEN 'RMQTY' THEN COALESCE(iv3.QTY_RM_I, 0)
            END) > 0
      AND MAX(DATEDIFF(DAY, CAST(iv3.DATERECD AS DATE), CAST(GETDATE() AS DATE))) >=
          CASE sl.Site_Type WHEN 'WFQ' THEN 14 WHEN 'RMQTY' THEN 7 END  -- eligible only
),

-- Expiring batches (positive remaining, Days_Until_Expiry <=90 and >0)
ExpiringBatches AS (
    SELECT *
    FROM EligibleInventory
    CROSS JOIN Config c
    WHERE Remaining_Quantity > 0
      AND Days_Until_Expiry <= c.Expiry_Rebalance_Threshold_Days
      AND Days_Until_Expiry > 0
),

-- Future demand and primary (WC) inventory for unmet calculation (inline simplified T-007)
FutureDemandAgg AS (
    SELECT
        ITEMNMBR AS Item_Number,
        SUM(
            CASE
                WHEN COALESCE(REMAINING, 0.0) > 0 THEN COALESCE(REMAINING, 0.0)
                WHEN COALESCE(DEDUCTIONS, 0.0) > 0 THEN COALESCE(DEDUCTIONS, 0.0)
                WHEN COALESCE(EXPIRY, 0.0) > 0 THEN COALESCE(EXPIRY, 0.0)
                ELSE 0.0
            END
        ) AS Total_Future_Demand
    FROM dbo.ETB_PAB_AUTO
    CROSS JOIN Config c
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
      AND STSDESCR <> 'Partially Received'
      AND TRY_CONVERT(DATE, DUEDATE) >= CAST(GETDATE() AS DATE)
      AND TRY_CONVERT(DATE, DUEDATE) <= DATEADD(DAY, c.Forward_Demand_Horizon_Days, CAST(GETDATE() AS DATE))
    GROUP BY ITEMNMBR
    HAVING SUM(
            CASE
                WHEN COALESCE(REMAINING, 0.0) > 0 THEN COALESCE(REMAINING, 0.0)
                WHEN COALESCE(DEDUCTIONS, 0.0) > 0 THEN COALESCE(DEDUCTIONS, 0.0)
                WHEN COALESCE(EXPIRY, 0.0) > 0 THEN COALESCE(EXPIRY, 0.0)
                ELSE 0.0
            END
        ) > 0
),

PrimaryInventoryAgg AS (
    SELECT
        ITEMNMBR AS Item_Number,
        SUM(QTY_Available) AS Total_Primary_Quantity
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
    WHERE LOCNCODE LIKE 'WC[_-]%'
      AND QTY_Available > 0
      AND LOT_NUMBER IS NOT NULL
      AND LOT_NUMBER <> ''
    GROUP BY ITEMNMBR
),

RiskItems AS (
    SELECT
        fd.Item_Number,
        fd.Total_Future_Demand,
        COALESCE(pi.Total_Primary_Quantity, 0.0) AS Total_Primary_Quantity,
        GREATEST(0.0, fd.Total_Future_Demand - COALESCE(pi.Total_Primary_Quantity, 0.0)) AS Unmet_Demand,
        CASE
            WHEN GREATEST(0.0, fd.Total_Future_Demand - COALESCE(pi.Total_Primary_Quantity, 0.0)) > 0
                AND (fd.Total_Future_Demand - COALESCE(pi.Total_Primary_Quantity, 0.0)) <= 0 THEN 'CRITICAL_STOCKOUT'  -- rough proxy
            WHEN GREATEST(0.0, fd.Total_Future_Demand - COALESCE(pi.Total_Primary_Quantity, 0.0)) > 0 THEN 'HIGH_RISK'
            ELSE 'HEALTHY'
        END AS Risk_Level
    FROM FutureDemandAgg fd
    LEFT JOIN PrimaryInventoryAgg pi ON fd.Item_Number = pi.Item_Number
    WHERE GREATEST(0.0, fd.Total_Future_Demand - COALESCE(pi.Total_Primary_Quantity, 0.0)) > 0
),

-- Cross-match expiring batches to risk items (same Item_Number)
RebalanceOpportunities AS (
    SELECT
        eb.Batch_ID,
        eb.Item_Number,
        eb.Source_Location,
        eb.Inventory_Type,
        eb.Remaining_Quantity,
        eb.Days_Until_Expiry,
        ri.Risk_Level,
        ri.Unmet_Demand,
        LEAST(eb.Remaining_Quantity, ri.Unmet_Demand) AS Recommended_Transfer_Quantity
    FROM ExpiringBatches eb
    INNER JOIN RiskItems ri ON eb.Item_Number = ri.Item_Number
)

SELECT
    Batch_ID,
    Item_Number,
    Source_Location,
    Inventory_Type,
    Remaining_Quantity,
    Days_Until_Expiry,
    Risk_Level,
    Unmet_Demand,
    Recommended_Transfer_Quantity,

    -- Priority matrix
    CASE
        WHEN Days_Until_Expiry <= 30 AND Risk_Level = 'CRITICAL_STOCKOUT' THEN 1
        WHEN Days_Until_Expiry <= 60 AND Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK') THEN 2
        WHEN Days_Until_Expiry <= 90 THEN 3
        ELSE 4
    END AS Transfer_Priority,

    -- Rebalancing type
    CASE
        WHEN Days_Until_Expiry <= 30 AND Risk_Level = 'CRITICAL_STOCKOUT' THEN 'URGENT_TRANSFER'
        WHEN Days_Until_Expiry <= 60 AND Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK') THEN 'EXPEDITE_TRANSFER'
        WHEN Days_Until_Expiry <= 90 THEN 'PLANNED_TRANSFER'
        ELSE 'MONITOR'
    END AS Rebalancing_Type,

    -- Business impact
    CASE
        WHEN Days_Until_Expiry <= 60 AND Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK') THEN 'HIGH'
        WHEN Days_Until_Expiry <= 90 AND Risk_Level = 'MEDIUM_RISK' THEN 'MEDIUM'  -- adjusted for available levels
        ELSE 'LOW'
    END AS Business_Impact

FROM RebalanceOpportunities
WHERE Recommended_Transfer_Quantity > 0
ORDER BY
    Transfer_Priority ASC,
    Days_Until_Expiry ASC,
    Recommended_Transfer_Quantity DESC,
    Item_Number ASC;