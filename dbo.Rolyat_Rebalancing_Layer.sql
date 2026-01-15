CREATE VIEW dbo.Rolyat_Rebalancing_Layer
AS
WITH Suppressed_Demand_Calc AS (
    -- Calculate suppression amount per demand row
    SELECT
        *,
        Base_Demand - effective_demand AS Suppressed_Demand,
        ABS(ATP_Running_Balance) AS ATP_Deficit
    FROM dbo.Rolyat_Final_Ledger_3
),

Next_PO_Supply AS (
    -- Find next PO arrivals within item-specific lead time window
    SELECT
        demand.ITEMNMBR,
        demand.Client_ID,
        demand.Site_ID,
        demand.ORDERNUMBER,
        demand.DUEDATE,

        COALESCE(SUM(
            CASE
                WHEN po.PO_Due_Date BETWEEN demand.DUEDATE
                    AND DATEADD(day, demand.Item_Lead_Time_Days, demand.DUEDATE)
                THEN po.Open_PO_Qty
                ELSE 0
            END
        ), 0) AS Next_PO_Qty,

        MIN(
            CASE
                WHEN po.PO_Due_Date BETWEEN demand.DUEDATE
                    AND DATEADD(day, demand.Item_Lead_Time_Days, demand.DUEDATE)
                THEN po.PO_Due_Date
                ELSE NULL
            END
        ) AS Earliest_PO_Arrival,

        COALESCE(DATEDIFF(day, demand.DUEDATE, MIN(
            CASE
                WHEN po.PO_Due_Date BETWEEN demand.DUEDATE
                    AND DATEADD(day, demand.Item_Lead_Time_Days, demand.DUEDATE)
                THEN po.PO_Due_Date
                ELSE NULL
            END
        )), 999) AS Days_Until_PO_Arrival

    FROM Suppressed_Demand_Calc demand
    LEFT JOIN dbo.Rolyat_PO_Detail po
        ON po.ITEMNMBR = demand.ITEMNMBR
        AND po.Site_ID = demand.Site_ID
        AND po.Is_Released = 1
        AND po.Is_Fully_Received = 0

    GROUP BY
        demand.ITEMNMBR, demand.Client_ID, demand.Site_ID,
        demand.ORDERNUMBER, demand.DUEDATE, demand.Item_Lead_Time_Days
),

Next_WFQ_Supply AS (
    -- Find WFQ batches projected to release within lead time
    SELECT
        demand.ITEMNMBR,
        demand.Client_ID,
        demand.Site_ID,
        demand.ORDERNUMBER,
        demand.DUEDATE,

        COALESCE(SUM(
            CASE
                WHEN wfq.Projected_Release_Date BETWEEN demand.DUEDATE
                    AND DATEADD(day, demand.Item_Lead_Time_Days, demand.DUEDATE)
                THEN wfq.QTY_ON_HAND
                ELSE 0
            END
        ), 0) AS Next_WFQ_Qty,

        MIN(
            CASE
                WHEN wfq.Projected_Release_Date BETWEEN demand.DUEDATE
                    AND DATEADD(day, demand.Item_Lead_Time_Days, demand.DUEDATE)
                THEN wfq.Projected_Release_Date
                ELSE NULL
            END
        ) AS Earliest_WFQ_Release

    FROM Suppressed_Demand_Calc demand
    LEFT JOIN dbo.Rolyat_WFQ_5 wfq
        ON wfq.ITEMNMBR = demand.ITEMNMBR
        AND wfq.Site_ID = demand.Site_ID
        AND wfq.Inventory_Type = 'WFQ'

    GROUP BY
        demand.ITEMNMBR, demand.Client_ID, demand.Site_ID,
        demand.ORDERNUMBER, demand.DUEDATE, demand.Item_Lead_Time_Days
),

Next_RMQTY_Supply AS (
    -- Find RMQTY batches eligible within lead time
    SELECT
        demand.ITEMNMBR,
        demand.Client_ID,
        demand.Site_ID,
        demand.ORDERNUMBER,
        demand.DUEDATE,

        COALESCE(SUM(
            CASE
                WHEN rmqty.Projected_Release_Date BETWEEN demand.DUEDATE
                    AND DATEADD(day, demand.Item_Lead_Time_Days, demand.DUEDATE)
                THEN rmqty.QTY_ON_HAND
                ELSE 0
            END
        ), 0) AS Next_RMQTY_Qty

    FROM Suppressed_Demand_Calc demand
    LEFT JOIN dbo.Rolyat_WFQ_5 rmqty
        ON rmqty.ITEMNMBR = demand.ITEMNMBR
        AND rmqty.Site_ID = demand.Site_ID
        AND rmqty.Inventory_Type = 'RMQTY'

    GROUP BY
        demand.ITEMNMBR, demand.Client_ID, demand.Site_ID,
        demand.ORDERNUMBER, demand.DUEDATE, demand.Item_Lead_Time_Days
),

Net_Replenishment_Calc AS (
    -- Calculate net replenishment need after timed hope sources
    SELECT
        demand.*,
        po.Next_PO_Qty,
        po.Earliest_PO_Arrival,
        po.Days_Until_PO_Arrival,
        wfq.Next_WFQ_Qty,
        wfq.Earliest_WFQ_Release,
        rmqty.Next_RMQTY_Qty,

        (po.Next_PO_Qty + wfq.Next_WFQ_Qty + rmqty.Next_RMQTY_Qty) AS Total_Timed_Hope_Supply,

        GREATEST(
            0,
            ATP_Deficit - (po.Next_PO_Qty + wfq.Next_WFQ_Qty + rmqty.Next_RMQTY_Qty)
        ) AS Net_Replenishment_Need

    FROM Suppressed_Demand_Calc demand
    LEFT JOIN Next_PO_Supply po
        ON po.ITEMNMBR = demand.ITEMNMBR
        AND po.Client_ID = demand.Client_ID
        AND po.Site_ID = demand.Site_ID
        AND po.ORDERNUMBER = demand.ORDERNUMBER
    LEFT JOIN Next_WFQ_Supply wfq
        ON wfq.ITEMNMBR = demand.ITEMNMBR
        AND wfq.Client_ID = demand.Client_ID
        AND wfq.Site_ID = demand.Site_ID
        AND wfq.ORDERNUMBER = demand.ORDERNUMBER
    LEFT JOIN Next_RMQTY_Supply rmqty
        ON rmqty.ITEMNMBR = demand.ITEMNMBR
        AND rmqty.Client_ID = demand.Client_ID
        AND rmqty.Site_ID = demand.Site_ID
        AND rmqty.ORDERNUMBER = demand.ORDERNUMBER
)

SELECT
    *
FROM Net_Replenishment_Calc

GO
