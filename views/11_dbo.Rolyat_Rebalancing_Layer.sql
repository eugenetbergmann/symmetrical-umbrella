/*
================================================================================
View: dbo.Rolyat_Rebalancing_Layer
Description: Rebalancing analysis with timed hope sources and net replenishment needs
Version: 1.1.0
Last Modified: 2026-01-24
Dependencies:
  - dbo.Rolyat_Final_Ledger_3
  - dbo.Rolyat_PO_Detail
  - dbo.ETB2_Inventory_Unified_v1 (replaces Rolyat_WFQ_5)

Purpose:
  - Calculates suppression amounts and ATP deficits per demand row
  - Identifies next PO arrivals within item-specific lead time windows
  - Identifies WFQ and RMQTY batches projected to release within lead time
  - Calculates net replenishment need after accounting for timed hope sources

Business Rules:
  - Lead time window is item-specific (Item_Lead_Time_Days)
  - PO supply only counts if released and not fully received
  - WFQ and RMQTY supply based on projected release dates
  - Net replenishment = ATP deficit - timed hope supply (min 0)
================================================================================
*/

SELECT
    demand.*,

    -- PO supply details
    po.Next_PO_Qty,
    po.Earliest_PO_Arrival,
    po.Days_Until_PO_Arrival,

    -- WFQ supply details
    wfq.Next_WFQ_Qty,
    wfq.Earliest_WFQ_Release,

    -- RMQTY supply details
    rmqty.Next_RMQTY_Qty,

    -- Total timed hope supply
    (po.Next_PO_Qty + wfq.Next_WFQ_Qty + rmqty.Next_RMQTY_Qty) AS Total_Timed_Hope_Supply,

    -- Net replenishment need after timed hope sources
    GREATEST(
        0,
        ATP_Deficit - (po.Next_PO_Qty + wfq.Next_WFQ_Qty + rmqty.Next_RMQTY_Qty)
    ) AS Net_Replenishment_Need

FROM (
    SELECT
        *,
        -- Amount suppressed by WC allocation
        Base_Demand - effective_demand AS ATP_Suppressed_Demand,
        -- Absolute ATP deficit (for replenishment calculation)
        ABS(effective_demand) AS ATP_Deficit
    FROM dbo.Rolyat_Final_Ledger_3
) AS demand

LEFT JOIN (
    SELECT
        demand_inner.ITEMNMBR,
        demand_inner.Client_ID,
        demand_inner.Site_ID,
        demand_inner.ORDERNUMBER,
        demand_inner.DUEDATE,

        -- Sum of PO quantities arriving within lead time
        COALESCE(SUM(
            CASE
                WHEN po.PO_Due_Date BETWEEN demand_inner.DUEDATE
                    AND DATEADD(DAY, demand_inner.Item_Lead_Time_Days, demand_inner.DUEDATE)
                THEN po.Open_PO_Qty
                ELSE 0
            END
        ), 0) AS Next_PO_Qty,

        -- Earliest PO arrival date within window
        MIN(
            CASE
                WHEN po.PO_Due_Date BETWEEN demand_inner.DUEDATE
                    AND DATEADD(DAY, demand_inner.Item_Lead_Time_Days, demand_inner.DUEDATE)
                THEN po.PO_Due_Date
                ELSE NULL
            END
        ) AS Earliest_PO_Arrival,

        -- Days until earliest PO arrival (999 if none)
        COALESCE(DATEDIFF(DAY, demand_inner.DUEDATE, MIN(
            CASE
                WHEN po.PO_Due_Date BETWEEN demand_inner.DUEDATE
                    AND DATEADD(DAY, demand_inner.Item_Lead_Time_Days, demand_inner.DUEDATE)
                THEN po.PO_Due_Date
                ELSE NULL
            END
        )), 999) AS Days_Until_PO_Arrival

    FROM (
        SELECT
            *,
            Base_Demand - effective_demand AS ATP_Suppressed_Demand,
            ABS(effective_demand) AS ATP_Deficit
        FROM dbo.Rolyat_Final_Ledger_3
    ) AS demand_inner
    LEFT JOIN dbo.Rolyat_PO_Detail po
        ON po.ITEMNMBR = demand_inner.ITEMNMBR
        AND po.Site_ID = demand_inner.Site_ID
        AND po.Is_Released = 1
        AND po.Is_Fully_Received = 0

    GROUP BY
        demand_inner.ITEMNMBR, demand_inner.Client_ID, demand_inner.Site_ID,
        demand_inner.ORDERNUMBER, demand_inner.DUEDATE, demand_inner.Item_Lead_Time_Days
) AS po
    ON po.ITEMNMBR = demand.ITEMNMBR
    AND po.Client_ID = demand.Client_ID
    AND po.Site_ID = demand.Site_ID
    AND po.ORDERNUMBER = demand.ORDERNUMBER

LEFT JOIN (
    SELECT
        demand_inner.ITEMNMBR,
        demand_inner.Client_ID,
        demand_inner.Site_ID,
        demand_inner.ORDERNUMBER,
        demand_inner.DUEDATE,

        -- Sum of WFQ quantities releasing within lead time
        COALESCE(SUM(
            CASE
                WHEN wfq.Projected_Release_Date BETWEEN demand_inner.DUEDATE
                    AND DATEADD(DAY, demand_inner.Item_Lead_Time_Days, demand_inner.DUEDATE)
                THEN wfq.QTY_ON_HAND
                ELSE 0
            END
        ), 0) AS Next_WFQ_Qty,

        -- Earliest WFQ release date within window
        MIN(
            CASE
                WHEN wfq.Projected_Release_Date BETWEEN demand_inner.DUEDATE
                    AND DATEADD(DAY, demand_inner.Item_Lead_Time_Days, demand_inner.DUEDATE)
                THEN wfq.Projected_Release_Date
                ELSE NULL
            END
        ) AS Earliest_WFQ_Release

    FROM (
        SELECT
            *,
            Base_Demand - effective_demand AS ATP_Suppressed_Demand,
            ABS(effective_demand) AS ATP_Deficit
        FROM dbo.Rolyat_Final_Ledger_3
    ) AS demand_inner
    LEFT JOIN dbo.ETB2_Inventory_Unified_v1 wfq
        ON wfq.ITEMNMBR = demand_inner.ITEMNMBR
        AND wfq.Site_ID = demand_inner.Site_ID
        AND wfq.Inventory_Type = 'WFQ_BATCH'

    GROUP BY
        demand_inner.ITEMNMBR, demand_inner.Client_ID, demand_inner.Site_ID,
        demand_inner.ORDERNUMBER, demand_inner.DUEDATE, demand_inner.Item_Lead_Time_Days
) AS wfq
    ON wfq.ITEMNMBR = demand.ITEMNMBR
    AND wfq.Client_ID = demand.Client_ID
    AND wfq.Site_ID = demand.Site_ID
    AND wfq.ORDERNUMBER = demand.ORDERNUMBER

LEFT JOIN (
    SELECT
        demand_inner.ITEMNMBR,
        demand_inner.Client_ID,
        demand_inner.Site_ID,
        demand_inner.ORDERNUMBER,
        demand_inner.DUEDATE,

        -- Sum of RMQTY quantities eligible within lead time
        COALESCE(SUM(
            CASE
                WHEN rmqty.Projected_Release_Date BETWEEN demand_inner.DUEDATE
                    AND DATEADD(DAY, demand_inner.Item_Lead_Time_Days, demand_inner.DUEDATE)
                THEN rmqty.QTY_ON_HAND
                ELSE 0
            END
        ), 0) AS Next_RMQTY_Qty

    FROM (
        SELECT
            *,
            Base_Demand - effective_demand AS ATP_Suppressed_Demand,
            ABS(effective_demand) AS ATP_Deficit
        FROM dbo.Rolyat_Final_Ledger_3
    ) AS demand_inner
    LEFT JOIN dbo.ETB2_Inventory_Unified_v1 rmqty
        ON rmqty.ITEMNMBR = demand_inner.ITEMNMBR
        AND rmqty.Site_ID = demand_inner.Site_ID
        AND rmqty.Inventory_Type = 'RMQTY_BATCH'

    GROUP BY
        demand_inner.ITEMNMBR, demand_inner.Client_ID, demand_inner.Site_ID,
        demand_inner.ORDERNUMBER, demand_inner.DUEDATE, demand_inner.Item_Lead_Time_Days
) AS rmqty
    ON rmqty.ITEMNMBR = demand.ITEMNMBR
    AND rmqty.Client_ID = demand.Client_ID
    AND rmqty.Site_ID = demand.Site_ID
    AND rmqty.ORDERNUMBER = demand.ORDERNUMBER
