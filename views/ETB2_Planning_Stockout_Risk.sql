-- ============================================================================
-- VIEW 4 of 6: ETB2_Planning_Stockout_Risk
-- PURPOSE: ATP balance and shortage risk analysis
-- PLANNER QUESTION: "Which items are at risk of stockout?"
-- SCREEN COLUMNS: 11 (fits 1920px)
-- ============================================================================

WITH

-- Future demand (next 90 days)
FutureDemand AS (
    SELECT
        ITEMNMBR                AS Item_Number,
        SUM(CASE
            WHEN COALESCE(REMAINING, 0) > 0 THEN REMAINING
            WHEN COALESCE(DEDUCTIONS, 0) > 0 THEN DEDUCTIONS
            WHEN COALESCE(EXPIRY, 0) > 0 THEN EXPIRY
            ELSE 0
        END) AS Total_Demand
    FROM dbo.ETB_PAB_AUTO
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
      AND STSDESCR <> 'Partially Received'
      AND TRY_CONVERT(DATE, DUEDATE) >= CAST(GETDATE() AS DATE)
      AND TRY_CONVERT(DATE, DUEDATE) <= DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    GROUP BY ITEMNMBR
    HAVING SUM(CASE
            WHEN COALESCE(REMAINING, 0) > 0 THEN REMAINING
            WHEN COALESCE(DEDUCTIONS, 0) > 0 THEN DEDUCTIONS
            WHEN COALESCE(EXPIRY, 0) > 0 THEN EXPIRY
            ELSE 0
        END) > 0
),

-- Available inventory (WC only for primary)
AvailableInventory AS (
    SELECT
        ITEMNMBR                AS Item_Number,
        SUM(QTY_Available)      AS Total_Available
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
    WHERE LOCNCODE LIKE 'WC[_-]%'
      AND QTY_Available > 0
    GROUP BY ITEMNMBR
),

-- Item master for descriptions
ItemMaster AS (
    SELECT DISTINCT
        ITEMNMBR,
        ITEMDESC,
        UOMSCHDL
    FROM dbo.IV00101
)

-- ============================================================
-- FINAL OUTPUT: 11 columns, planner-optimized order
-- ============================================================
SELECT
    -- IDENTIFY (what item?) - 3 columns
    COALESCE(d.Item_Number, i.Item_Number) AS Item_Number,
    im.ITEMDESC             AS Item_Description,
    im.UOMSCHDL             AS Unit_Of_Measure,
    
    -- QUANTIFY (the math) - 4 columns
    COALESCE(d.Total_Demand, 0) AS Demand_90_Days,
    COALESCE(i.Total_Available, 0) AS WC_Available,
    COALESCE(i.Total_Available, 0) - COALESCE(d.Total_Demand, 0) AS ATP_Balance,
    CASE 
        WHEN COALESCE(i.Total_Available, 0) < COALESCE(d.Total_Demand, 0)
        THEN COALESCE(d.Total_Demand, 0) - COALESCE(i.Total_Available, 0)
        ELSE 0
    END AS Shortage_Quantity,
    
    -- DECIDE (risk assessment) - 4 columns
    CASE
        WHEN COALESCE(i.Total_Available, 0) = 0 THEN 'CRITICAL'
        WHEN COALESCE(i.Total_Available, 0) < COALESCE(d.Total_Demand, 0) * 0.5 THEN 'HIGH'
        WHEN COALESCE(i.Total_Available, 0) < COALESCE(d.Total_Demand, 0) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Risk_Level,
    CASE
        WHEN COALESCE(i.Total_Available, 0) > 0 AND COALESCE(d.Total_Demand, 0) > 0
        THEN CAST(COALESCE(i.Total_Available, 0) / NULLIF(COALESCE(d.Total_Demand, 0), 0) AS decimal(10,2))
        ELSE 999.99
    END AS Coverage_Ratio,
    CASE
        WHEN COALESCE(i.Total_Available, 0) = 0 THEN 1
        WHEN COALESCE(i.Total_Available, 0) < COALESCE(d.Total_Demand, 0) * 0.5 THEN 2
        WHEN COALESCE(i.Total_Available, 0) < COALESCE(d.Total_Demand, 0) THEN 3
        ELSE 4
    END AS Priority,
    CASE
        WHEN COALESCE(i.Total_Available, 0) = 0 THEN 'URGENT: No inventory'
        WHEN COALESCE(i.Total_Available, 0) < COALESCE(d.Total_Demand, 0) * 0.5 THEN 'EXPEDITE: Low coverage'
        WHEN COALESCE(i.Total_Available, 0) < COALESCE(d.Total_Demand, 0) THEN 'MONITOR: Partial coverage'
        ELSE 'OK: Adequate coverage'
    END AS Recommendation

FROM FutureDemand d
FULL OUTER JOIN AvailableInventory i
    ON d.Item_Number = i.Item_Number
LEFT JOIN ItemMaster im
    ON COALESCE(d.Item_Number, i.Item_Number) = im.ITEMNMBR

WHERE COALESCE(d.Total_Demand, 0) > 0
   OR COALESCE(i.Total_Available, 0) > 0

ORDER BY
    Priority ASC,
    Shortage_Quantity DESC,
    Item_Number ASC;

GO

-- ============================================================
-- TEST QUERIES
-- ============================================================
/*
-- Risk distribution
SELECT Risk_Level,
       COUNT(*) AS Item_Count,
       SUM(Shortage_Quantity) AS Total_Shortage
FROM dbo.ETB2_Planning_Stockout_Risk
GROUP BY Risk_Level
ORDER BY
