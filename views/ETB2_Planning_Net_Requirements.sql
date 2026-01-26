WITH

-- Configuration defaults (expand/adjust as needed)
Config AS (
    SELECT
        90 AS Forward_Demand_Horizon_Days,   -- Demand aggregation period
        30 AS Safety_Stock_Days,             -- Default safety buffer (common value; override if config populated)
        'DAYS_OF_SUPPLY' AS Safety_Stock_Method
),

-- Future cleaned demand (inline exact T-002 logic, future only, within horizon)
FutureDemandRaw AS (
    SELECT
        ITEMNMBR AS Item_Number,
        TRY_CONVERT(DATE, DUEDATE) AS Due_Date,
        COALESCE(REMAINING, 0.0) AS Remaining_Qty,
        COALESCE(DEDUCTIONS, 0.0) AS Deductions_Qty,
        COALESCE(EXPIRY, 0.0) AS Expiry_Qty
    FROM dbo.ETB_PAB_AUTO
    CROSS JOIN Config c
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
      AND STSDESCR <> 'Partially Received'
      AND TRY_CONVERT(DATE, DUEDATE) >= CAST(GETDATE() AS DATE)
      AND TRY_CONVERT(DATE, DUEDATE) <= DATEADD(DAY, c.Forward_Demand_Horizon_Days, CAST(GETDATE() AS DATE))
),

FutureDemand AS (
    SELECT
        Item_Number,
        CASE
            WHEN Remaining_Qty > 0 THEN Remaining_Qty
            WHEN Deductions_Qty > 0 THEN Deductions_Qty
            WHEN Expiry_Qty > 0 THEN Expiry_Qty
            ELSE 0.0
        END AS Base_Demand_Quantity
    FROM FutureDemandRaw
    WHERE (Remaining_Qty + Deductions_Qty + Expiry_Qty) > 0
),

DemandAgg AS (
    SELECT
        Item_Number,
        SUM(Base_Demand_Quantity) AS Total_Future_Demand
    FROM FutureDemand
    GROUP BY Item_Number
),

-- Eligible WC inventory total (primary - always eligible, inline T-003 sources)
PrimaryInventory AS (
    SELECT
        pib.ITEMNMBR AS Item_Number,
        SUM(pib.QTY_Available) AS Total_Primary_Quantity
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib
    WHERE pib.LOCNCODE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
    GROUP BY pib.ITEMNMBR
),

-- Eligible WFQ + RMQTY inventory total (alternate - only after hold elapsed, inline T-004 sources)
AlternateInventory AS (
    SELECT
        iv3.ITEMNMBR AS Item_Number,
        SUM(
            CASE
                WHEN sl.Site_Type = 'WFQ'   THEN COALESCE(iv3.ATYALLOC, 0)
                WHEN sl.Site_Type = 'RMQTY' THEN COALESCE(iv3.QTY_RM_I, 0)
                ELSE 0
            END
        ) AS Total_Alternate_Quantity
    FROM dbo.IV00300 iv3
    INNER JOIN dbo.IV00101 iv1 ON iv3.ITEMNMBR = iv1.ITEMNMBR
    INNER JOIN (SELECT LOCNCODE, Site_Type FROM (VALUES
        ('WFQ-CA01', 'WFQ'), ('WFQ-NY01', 'WFQ'),
        ('RMQTY-CA01', 'RMQTY'), ('RMQTY-NY01', 'RMQTY')
        -- Expand with real locations
    ) AS s(LOCNCODE, Site_Type)) sl ON iv3.LOCNCODE = sl.LOCNCODE
    CROSS JOIN Config c
    GROUP BY iv3.ITEMNMBR
    HAVING SUM(
            CASE
                WHEN sl.Site_Type = 'WFQ'   THEN COALESCE(iv3.ATYALLOC, 0)
                WHEN sl.Site_Type = 'RMQTY' THEN COALESCE(iv3.QTY_RM_I, 0)
                ELSE 0
            END
        ) > 0
      AND MAX(DATEDIFF(DAY, CAST(iv3.DATERECD AS DATE), CAST(GETDATE() AS DATE))) >=
          MAX(CASE sl.Site_Type WHEN 'WFQ' THEN 14 WHEN 'RMQTY' THEN 7 END)  -- rough hold check; precise would need per batch
),

-- All relevant items (demand or inventory)
AllItems AS (
    SELECT Item_Number FROM DemandAgg
    UNION
    SELECT Item_Number FROM PrimaryInventory
    UNION
    SELECT Item_Number FROM AlternateInventory
),

-- Aggregated per item
ItemSummary AS (
    SELECT
        ai.Item_Number,
        itm.ITEMDESC AS Item_Description,
        itm.UOMSCHDL AS Unit_Of_Measure,
        COALESCE(da.Total_Future_Demand, 0.0) AS Total_Future_Demand,
        COALESCE(pi.Total_Primary_Quantity, 0.0) AS Total_Primary_Inventory,
        COALESCE(ai_alt.Total_Alternate_Quantity, 0.0) AS Total_Alternate_Inventory
    FROM AllItems ai
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
        ON LTRIM(RTRIM(ai.Item_Number)) = LTRIM(RTRIM(itm.ITEMNMBR))
    LEFT JOIN DemandAgg da ON ai.Item_Number = da.Item_Number
    LEFT JOIN PrimaryInventory pi ON ai.Item_Number = pi.Item_Number
    LEFT JOIN AlternateInventory ai_alt ON ai.Item_Number = ai_alt.Item_Number
)

SELECT
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Total_Future_Demand,
    Total_Primary_Inventory,
    Total_Alternate_Inventory,

    -- Core calculations
    LEAST(Total_Primary_Inventory, Total_Future_Demand) AS Allocated_Primary_Quantity,
    Total_Primary_Inventory - LEAST(Total_Primary_Inventory, Total_Future_Demand) AS Remaining_Primary_Quantity,
    GREATEST(0.0, Total_Future_Demand - Total_Primary_Inventory) AS Unmet_Demand,
    LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand AS ATP_Balance,  -- negative = shortage

    -- Safety stock and days of supply
    CASE
        WHEN Total_Future_Demand > 0
        THEN Total_Future_Demand / c.Forward_Demand_Horizon_Days
        ELSE 0.0
    END AS Average_Daily_Demand,
    CASE
        WHEN Total_Future_Demand > 0
        THEN (Total_Future_Demand / c.Forward_Demand_Horizon_Days) * c.Safety_Stock_Days
        ELSE 0.0
    END AS Safety_Stock_Level,

    CASE
        WHEN Total_Future_Demand > 0 AND (Total_Future_Demand / c.Forward_Demand_Horizon_Days) > 0
        THEN Remaining_Primary_Quantity / (Total_Future_Demand / c.Forward_Demand_Horizon_Days)
        ELSE 9999.0  -- large number if no demand
    END AS Days_Of_Supply,

    -- Net requirement (exact cascading logic)
    CASE
        WHEN (LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand) < 0
            THEN ABS(LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand) +
                 CASE WHEN Total_Future_Demand > 0 THEN (Total_Future_Demand / c.Forward_Demand_Horizon_Days) * c.Safety_Stock_Days ELSE 0 END
        WHEN (LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand) <
             CASE WHEN Total_Future_Demand > 0 THEN (Total_Future_Demand / c.Forward_Demand_Horizon_Days) * c.Safety_Stock_Days ELSE 0 END
            THEN
                 CASE WHEN Total_Future_Demand > 0 THEN (Total_Future_Demand / c.Forward_Demand_Horizon_Days) * c.Safety_Stock_Days ELSE 0 END
                 - (LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand)
        WHEN GREATEST(0.0, Total_Future_Demand - Total_Primary_Inventory) > 0
            THEN GREATEST(0.0, Total_Future_Demand - Total_Primary_Inventory)
        ELSE 0.0
    END AS Net_Requirement_Quantity,

    -- Status and priority
    CASE
        WHEN (LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand) < 0 THEN 'CRITICAL_SHORTAGE'
        WHEN (LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand) <
             CASE WHEN Total_Future_Demand > 0 THEN (Total_Future_Demand / c.Forward_Demand_Horizon_Days) * c.Safety_Stock_Days ELSE 0 END
            THEN 'BELOW_SAFETY_STOCK'
        WHEN GREATEST(0.0, Total_Future_Demand - Total_Primary_Inventory) > 0 THEN 'FORECASTED_SHORTAGE'
        ELSE 'ADEQUATE'
    END AS Requirement_Status,

    CASE
        WHEN (LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand) < 0 THEN 1
        WHEN (LEAST(Total_Primary_Inventory, Total_Future_Demand) - Total_Future_Demand) <
             CASE WHEN Total_Future_Demand > 0 THEN (Total_Future_Demand / c.Forward_Demand_Horizon_Days) * c.Safety_Stock_Days ELSE 0 END
            THEN 2
        WHEN GREATEST(0.0, Total_Future_Demand - Total_Primary_Inventory) > 0 THEN 3
        ELSE 4
    END AS Requirement_Priority

FROM ItemSummary
CROSS JOIN Config c
WHERE Total_Future_Demand > 0
   OR Total_Primary_Inventory > 0
   OR Total_Alternate_Inventory > 0
ORDER BY
    Requirement_Priority ASC,
    Net_Requirement_Quantity DESC,
    Item_Number ASC;