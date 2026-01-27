/*******************************************************************************
* View Name:    ETB2_PAB_EventLedger_v1
* Deploy Order: 17 of 17 ⚠️ DEPLOY BETWEEN FILES 13 AND 14
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Audit trail for PAB order changes - tracks all order modifications
* Grain:        One row per order event (order created, modified, received, cancelled)
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB3_Demand_Cleaned_Base (view 04 - deploy first)
*   ✓ dbo.POP10100 (PO Header - external table)
*   ✓ dbo.POP10110 (PO Detail - external table)
*   ✓ dbo.IV00102 (Item quantities - external table)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_PAB_EventLedger_v1
* 8. Refresh Views folder
*
* ⚠️ IMPORTANT: Deploy this BEFORE file 14 (Campaign_Risk_Adequacy)
* Deploy sequence: 01→02→03→04→05→06→07→08→09→10→11→12→13→**17**→14→15→16
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_PAB_EventLedger_v1
*   Expected: Event history from PAB orders
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    -- Event identification
    LTRIM(RTRIM(p.PONUMBER)) AS Order_Number,
    LTRIM(RTRIM(p.VENDORID)) AS Vendor_ID,
    
    -- Event details
    pd.ITEMNMBR AS Item_Number,
    pd.UOFM AS UOM,
    pd.QTYORDER AS Ordered_Qty,
    pd.QTYRECEIVED AS Received_Qty,
    pd.QTYREMGTD AS Remaining_Qty,
    
    -- Event type classification
    CASE 
        WHEN pd.QTYRECEIVED > 0 THEN 'RECEIVED'
        WHEN pd.QTYREMGTD = pd.QTYORDER THEN 'OPEN'
        WHEN pd.QTYREMGTD < pd.QTYORDER AND pd.QTYRECEIVED > 0 THEN 'PARTIAL'
        ELSE 'PENDING'
    END AS Event_Type,
    
    -- Date fields
    p.DOCDATE AS Order_Date,
    p.REQDATE AS Required_Date,
    GETDATE() AS ETB2_Load_Date,

    -- Item description from item master
    ISNULL(i.ITEMDESC, '') AS Item_Description
    
FROM dbo.POP10100 p
INNER JOIN dbo.POP10110 pd ON p.PONUMBER = pd.PONUMBER
LEFT JOIN dbo.IV00102 i ON pd.ITEMNMBR = i.ITEMNMBR
WHERE pd.ITEMNMBR IN (SELECT ITEMNMBR FROM dbo.ETB3_Demand_Cleaned_Base)

UNION ALL

-- Demand events from PAB
SELECT 
    LTRIM(RTRIM(pab.ORDERNUMBER)) AS Order_Number,
    '' AS Vendor_ID,  -- No vendor in PAB
    LTRIM(RTRIM(pab.ITEMNMBR)) AS Item_Number,
    '' AS UOM,  -- No UOM in PAB
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pab.Running_Balance))) = 1 
        THEN CAST(LTRIM(RTRIM(pab.Running_Balance)) AS DECIMAL(18,5))
        ELSE 0 
    END AS Ordered_Qty,
    0 AS Received_Qty,
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pab.Running_Balance))) = 1 
        THEN CAST(LTRIM(RTRIM(pab.Running_Balance)) AS DECIMAL(18,5))
        ELSE 0 
    END AS Remaining_Qty,
    'DEMAND' AS Event_Type,
    pab.DUEDATE AS Order_Date,
    pab.DUEDATE AS Required_Date,
    GETDATE() AS ETB2_Load_Date,
    ISNULL(vi.ITEMDESC, '') AS Item_Description
FROM dbo.ETB_PAB_AUTO pab
LEFT JOIN dbo.Prosenthal_Vendor_Items vi ON LTRIM(RTRIM(pab.ITEMNMBR)) = LTRIM(RTRIM(vi.[Item Number]))
WHERE pab.STSDESCR <> 'Partially Received'
    AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '60.%'
    AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '70.%'

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Event summary:
   SELECT 
       Event_Type,
       COUNT(*) AS Events,
       SUM(Ordered_Qty) AS Total_Qty
   FROM dbo.ETB2_PAB_EventLedger_v1
   GROUP BY Event_Type
   ORDER BY Event_Type

2. Recent events:
   SELECT TOP 10
       Order_Number,
       Item_Number,
       Event_Type,
       Ordered_Qty,
       Order_Date
   FROM dbo.ETB2_PAB_EventLedger_v1
   ORDER BY ETB2_Load_Date DESC

3. PO vs Demand events:
   SELECT 
       CASE WHEN Vendor_ID = '' THEN 'DEMAND' ELSE 'PO' END AS Source,
       COUNT(*) AS Events
   FROM dbo.ETB2_PAB_EventLedger_v1
   GROUP BY CASE WHEN Vendor_ID = '' THEN 'DEMAND' ELSE 'PO' END
*/
