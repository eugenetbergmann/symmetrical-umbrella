-- [T-002] Cleaned Base Demand – Exact Rolyat Preservation
-- Purpose: Returns cleaned, prioritized base demand records ready for planners or downstream allocation.
--          Exact replication of original Rolyat_Cleaned_Base_Demand_1 logic:
--          - Excludes 60.x / 70.x items and partially received orders
--          - Prioritizes Remaining > Deductions > Expiry for Base_Demand_Qty
--          - Flags records within ±21 day active planning window
--          - Cleans order numbers and standardizes dates/quantities
--          Sorted by Due_Date ASC, then Base_Demand_Qty DESC for immediate usability in Excel.

WITH RawDemand AS (
    SELECT 
        ORDERNUMBER,
        ITEMNMBR,
        DUEDATE,
        REMAINING,
        DEDUCTIONS,
        EXPIRY,
        STSDESCR,
        [Date + Expiry] AS Date_Expiry_String,
        MRP_IssueDate,
        TRY_CONVERT(DATE, DUEDATE) AS Due_Date_Clean,
        TRY_CONVERT(DATE, [Date + Expiry]) AS Expiry_Date_Clean
    FROM dbo.ETB_PAB_AUTO
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
      AND STSDESCR <> 'Partially Received'
),

CleanedDemand AS (
    SELECT 
        ORDERNUMBER,
        ITEMNMBR,
        Due_Date_Clean AS Due_Date,
        COALESCE(REMAINING, 0.0) AS Remaining_Qty,
        COALESCE(DEDUCTIONS, 0.0) AS Deductions_Qty,
        COALESCE(EXPIRY, 0.0) AS Expiry_Qty,
        Expiry_Date_Clean AS Expiry_Date,
        MRP_IssueDate,
        CASE 
            WHEN COALESCE(REMAINING, 0) > 0 THEN Remaining_Qty
            WHEN COALESCE(DEDUCTIONS, 0) > 0 THEN Deductions_Qty
            WHEN COALESCE(EXPIRY, 0) > 0 THEN Expiry_Qty
            ELSE 0.0
        END AS Base_Demand_Qty,
        CASE 
            WHEN COALESCE(REMAINING, 0) > 0 THEN 'Remaining'
            WHEN COALESCE(DEDUCTIONS, 0) > 0 THEN 'Deductions'
            WHEN COALESCE(EXPIRY, 0) > 0 THEN 'Expiry'
            ELSE 'Zero'
        END AS Demand_Priority_Type,
        CASE 
            WHEN Due_Date_Clean BETWEEN 
                DATEADD(DAY, -21, CAST(GETDATE() AS DATE)) 
                AND DATEADD(DAY, 21, CAST(GETDATE() AS DATE))
            THEN 1 ELSE 0 
        END AS Is_Within_Active_Planning_Window,
        -- Sort priority matches original: 1=BEG_BAL (not here), 2=POs, 3=Demand, 4=Expiry, 5=Other
        CASE Demand_Priority_Type
            WHEN 'Remaining'   THEN 3
            WHEN 'Deductions'  THEN 3
            WHEN 'Expiry'      THEN 4
            ELSE 5
        END AS Event_Sort_Priority,
        -- Clean order number: remove MO-, -, /, ., # and trim
        TRIM(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(ORDERNUMBER, 'MO-', ''),
                        '-', ''
                    ),
                    '/', ''
                ),
                '#', ''
            )
        ) AS Clean_Order_Number
    FROM RawDemand
    WHERE Due_Date_Clean IS NOT NULL  -- only valid dates
      AND (COALESCE(REMAINING, 0) + COALESCE(DEDUCTIONS, 0) + COALESCE(EXPIRY, 0)) > 0  -- exclude zero-impact rows
)

SELECT 
    Clean_Order_Number              AS Order_Number,
    ITEMNMBR                        AS Item_Number,
    Due_Date,
    Base_Demand_Qty                 AS Base_Demand_Quantity,
    Remaining_Qty,
    Deductions_Qty,
    Expiry_Qty,
    Demand_Priority_Type,
    Is_Within_Active_Planning_Window,
    Event_Sort_Priority,
    Expiry_Date,
    MRP_IssueDate
FROM CleanedDemand
ORDER BY 
    Due_Date ASC,
    Base_Demand_Quantity DESC,
    Event_Sort_Priority ASC,
    Item_Number ASC;
