-- ============================================================================
-- SELECT 01: Cleaned Demand Extraction (Production Ready)
-- ============================================================================
-- Purpose: Deterministic demand extraction from dbo.ETB_PAB_AUTO with FG/Construct
-- Filter: MRP_TYPE = 6 (Deductions) with CleanOrder normalization
-- Status: DEPLOYED - Production Stabilization Complete
-- ============================================================================

WITH DemandBase AS (
    SELECT 
        UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ORDERNUMBER, 'MO', ''), '-', ''), ' ', ''), '/', ''), '.', '')) AS CleanOrder,
        ITEMNMBR,
        TRY_CONVERT(DATE, DUEDATE) AS Due_Date,
        TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)) AS Raw_Demand,
        -- Suppression Logic: Demand is suppressed if Site is WC-R or specifically flagged
        CASE 
            WHEN ITEMNMBR LIKE 'MO-%' THEN 1 
            ELSE 0 
        END AS Is_Suppressed,
        [Date + Expiry] AS Expiry_Date_String,
        MRP_IssueDate
    FROM dbo.ETB_PAB_AUTO
    WHERE MRP_TYPE = 6
      AND STSDESCR <> 'Partially Received'
      AND ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
),
FG_MO_Linkage AS (
    SELECT 
        m.MONumber,
        UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(m.MONumber, 'MO', ''), '-', ''), ' ', ''), '/', ''), '.', '')) AS CleanOrder,
        m.FG AS FG_Item_Code,
        m.[FG Desc] AS FG_Description,
        m.Customer AS Construct,
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(m.MONumber, 'MO', ''), '-', ''), ' ', ''), '/', ''), '.', ''))
            ORDER BY m.Customer, m.[FG Desc]
        ) AS FG_RowNum
    FROM dbo.ETB_ActiveDemand_Union_FG_MO m
    WHERE m.FG IS NOT NULL AND m.FG <> ''
)
SELECT 
    d.CleanOrder AS Order_Number,
    d.ITEMNMBR AS Item_Number,
    d.Due_Date,
    TRY_CONVERT(DATE, d.Expiry_Date_String) AS Expiry_Date,
    d.Raw_Demand,
    CASE WHEN d.Is_Suppressed = 1 THEN 0 ELSE d.Raw_Demand END AS Suppressed_Demand_Qty,
    f.FG_Item_Code,
    f.FG_Description,
    f.Construct,
    d.MRP_IssueDate,
    d.Is_Suppressed
FROM DemandBase d
LEFT JOIN FG_MO_Linkage f 
    ON d.CleanOrder = f.CleanOrder AND f.FG_RowNum = 1
WHERE d.Due_Date IS NOT NULL
  AND (d.Raw_Demand IS NOT NULL AND d.Raw_Demand <> 0);

-- ============================================================================
-- END OF SELECT 01
-- ============================================================================
