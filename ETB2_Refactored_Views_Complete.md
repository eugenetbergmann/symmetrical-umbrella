# ETB2 Pipeline - Complete Refactored Views Documentation

**Status:** ✅ PRODUCTION READY  
**Last Updated:** 2026-01-28  
**Database:** MED (usca2w100968\gpprod)  
**Version:** 1.0  

---

## Table of Contents

1. [Overview](#overview)
2. [Deployment Order](#deployment-order)
3. [Quick Start Guide](#quick-start-guide)
4. [View Reference](#view-reference)
   - [Configuration Views (01-03)](#configuration-views-01-03)
   - [Demand Views (04)](#demand-views-04)
   - [Inventory Views (05-07)](#inventory-views-05-07)
   - [Planning Views (08-10)](#planning-views-08-10)
   - [Campaign Views (11-16)](#campaign-views-11-16)
   - [Event Ledger (17)](#event-ledger-17)
5. [External Dependencies](#external-dependencies)
6. [Column Schema Reference](#column-schema-reference)

---

## Overview

This document contains all 17 refactored ETB2 views consolidated into a single portable markdown file. These views form a complete supply chain analytics pipeline for novel-modality CDMO operations.

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONSUMPTION LAYER                            │
│  (Campaign Analytics, Executive KPIs, Risk Assessment)          │
│  Views: 11-16                                                   │
├─────────────────────────────────────────────────────────────────┤
│                    PLANNING LAYER                               │
│  (Net Requirements, Stockout Risk, Rebalancing)                 │
│  Views: 08-10                                                   │
├─────────────────────────────────────────────────────────────────┤
│                    INVENTORY LAYER                              │
│  (WC Batches, Quarantine, Unified Inventory)                    │
│  Views: 05-07                                                   │
├─────────────────────────────────────────────────────────────────┤
│                    DEMAND LAYER                                 │
│  (Cleaned Base Demand)                                          │
│  Views: 04                                                      │
├─────────────────────────────────────────────────────────────────┤
│                    CONFIGURATION LAYER                          │
│  (Lead Times, Part Pooling, Active Config)                      │
│  Views: 01-03                                                   │
├─────────────────────────────────────────────────────────────────┤
│                    EVENT LEDGER                                 │
│  (Audit Trail, PAB Order Tracking)                              │
│  Views: 17                                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Deployment Order

**CRITICAL:** Views must be deployed in this exact sequence due to dependencies.

| Order | View Name | Dependencies |
|-------|-----------|--------------|
| 01 | ETB2_Config_Lead_Times | None (external: IV00101) |
| 02 | ETB2_Config_Part_Pooling | None (external: IV00101) |
| 02B | ETB2_Config_Items | None (external: Prosenthal_Vendor_Items) |
| 03 | ETB2_Config_Active | Views 01, 02 |
| 04 | ETB2_Demand_Cleaned_Base | View 02B, external: ETB_PAB_AUTO |
| 05 | ETB2_Inventory_WC_Batches | External: Prosenthal_INV_BIN_QTY_wQTYTYPE, IV00101 |
| 06 | ETB2_Inventory_Quarantine_Restricted | External: IV00300, IV00101 |
| 07 | ETB2_Inventory_Unified | Views 05, 06 |
| 08 | ETB2_Planning_Net_Requirements | View 04, 02B |
| 09 | ETB2_Planning_Stockout | Views 07, 08, 02B |
| 10 | ETB2_Planning_Rebalancing_Opportunities | Views 04, 07, external: Prosenthal_INV_BIN_QTY_wQTYTYPE |
| 11 | ETB2_Campaign_Normalized_Demand | View 04 |
| 12 | ETB2_Campaign_Concurrency_Window | View 11 |
| 13 | ETB2_Campaign_Collision_Buffer | Views 11, 12 |
| 17 | ETB2_PAB_EventLedger_v1 | View 04, external: POP10100, POP10110 |
| 14 | ETB2_Campaign_Risk_Adequacy | Views 13, 17, 07 |
| 15 | ETB2_Campaign_Absorption_Capacity | View 14 |
| 16 | ETB2_Campaign_Model_Data_Gaps | Views 03, 07, 04, 11 |

**Note:** View 17 must be deployed BETWEEN views 13 and 14.

---

## Quick Start Guide

### For Each View:

1. **Copy the SQL** from the view section below
2. **Open SSMS** → New Query window
3. **Paste** the SQL statement
4. **Execute (F5)** to test
5. **Highlight all (Ctrl+A)**
6. **Right-click → Create View**
7. **Save as:** `dbo.ViewName`

**Total Deployment Time:** ~60 minutes (3-4 minutes per view)

---

## View Reference

---

## Configuration Views (01-03)

### View 01: ETB2_Config_Lead_Times

**Purpose:** Lead time configuration with 30-day defaults for novel-modality CDMO  
**Grain:** One row per item from item master  
**Dependencies:** `dbo.IV00101` (Item master - external table)  

```sql
-- ============================================================================
-- VIEW 01: dbo.ETB2_Config_Lead_Times
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Lead_Times
-- ============================================================================
-- Purpose: Lead time configuration with 30-day defaults for novel-modality CDMO
-- Grain: One row per item from item master
-- Dependencies: dbo.IV00101 (Item master - external table)
-- Last Updated: 2026-01-28
-- ============================================================================

SELECT DISTINCT
    ITEMNMBR,
    30 AS Lead_Time_Days,  -- Conservative default for novel-modality CDMO
    GETDATE() AS Last_Updated,
    'SYSTEM_DEFAULT' AS Config_Source
FROM dbo.IV00101 WITH (NOLOCK)
WHERE ITEMNMBR IS NOT NULL
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR | Item number (PK) |
| Lead_Time_Days | INT | Default 30 days |
| Last_Updated | DATETIME | Timestamp |
| Config_Source | VARCHAR | 'SYSTEM_DEFAULT' |

---

### View 02: ETB2_Config_Part_Pooling

**Purpose:** Pooling classification defaults for inventory strategy  
**Grain:** One row per item from item master  
**Dependencies:** `dbo.IV00101` (Item master - external table)  

```sql
-- ============================================================================
-- VIEW 02: dbo.ETB2_Config_Part_Pooling
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Part_Pooling
-- ============================================================================
-- Purpose: Pooling classification defaults for inventory strategy
-- Grain: One row per item from item master
-- Dependencies: dbo.IV00101 (Item master - external table)
-- Last Updated: 2026-01-28
-- ============================================================================

SELECT DISTINCT
    ITEMNMBR,
    'Dedicated' AS Pooling_Classification,  -- Conservative default: dedicated resources
    1.4 AS Pooling_Multiplier,              -- Dedicated multiplier per pooling strategy
    'SYSTEM_DEFAULT' AS Config_Source
FROM dbo.IV00101 WITH (NOLOCK)
WHERE ITEMNMBR IS NOT NULL
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR | Item number (PK) |
| Pooling_Classification | VARCHAR | 'Dedicated' default |
| Pooling_Multiplier | DECIMAL | 1.4 for dedicated |
| Config_Source | VARCHAR | 'SYSTEM_DEFAULT' |

---

### View 02B: ETB2_Config_Items

**Purpose:** Master item configuration from Prosenthal_Vendor_Items  
**Grain:** One row per item  
**Dependencies:** `dbo.Prosenthal_Vendor_Items` (vendor item reference)  

```sql
-- ============================================================================
-- VIEW 02B: dbo.ETB2_Config_Items
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Items
-- ============================================================================
-- Purpose: Master item configuration from Prosenthal_Vendor_Items
-- Grain: One row per item
-- Dependencies:
--   - dbo.Prosenthal_Vendor_Items (vendor item reference)
-- Outputs:
--   - Item_Number (PK): Unique item identifier
--   - Item_Description: Primary item description
--   - UOM_Schedule: Unit of measure schedule code
--   - Purchasing_UOM: Purchasing UOM from vendor data
--   - Is_Active: Whether item is active in vendor system
-- Last Updated: 2026-01-28
-- ============================================================================

SELECT
    [Item Number] AS Item_Number,
    ITEMDESC AS Item_Description,
    PRCHSUOM AS Purchasing_UOM,
    UOMSCHDL AS UOM_Schedule
FROM dbo.Prosenthal_Vendor_Items WITH (NOLOCK)
WHERE Active = 'Yes';

-- ============================================================================
-- END OF VIEW 02B
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Unique item identifier |
| Item_Description | VARCHAR | Primary item description |
| Purchasing_UOM | VARCHAR | Purchasing unit of measure |
| UOM_Schedule | VARCHAR | UOM schedule code |

---

### View 03: ETB2_Config_Active

**Purpose:** Unified configuration layer combining lead times and pooling  
**Grain:** One row per item (COALESCE logic for multi-tier hierarchy)  
**Dependencies:** Views 01, 02  

```sql
-- ============================================================================
-- VIEW 03: dbo.ETB2_Config_Active
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Config_Active
-- ============================================================================
-- Purpose: Unified configuration layer combining lead times and pooling
-- Grain: One row per item (COALESCE logic for multi-tier hierarchy)
-- Dependencies:
--   - dbo.ETB2_Config_Lead_Times (view 01)
--   - dbo.ETB2_Config_Part_Pooling (view 02)
-- Last Updated: 2026-01-28
-- ============================================================================

SELECT
    COALESCE(lt.ITEMNMBR, pp.ITEMNMBR) AS ITEMNMBR,
    COALESCE(lt.Lead_Time_Days, 30) AS Lead_Time_Days,
    COALESCE(pp.Pooling_Classification, 'Dedicated') AS Pooling_Classification,
    COALESCE(pp.Pooling_Multiplier, 1.4) AS Pooling_Multiplier,
    CASE
        WHEN lt.ITEMNMBR IS NOT NULL AND pp.ITEMNMBR IS NOT NULL THEN 'Both_Configured'
        WHEN lt.ITEMNMBR IS NOT NULL THEN 'Lead_Time_Only'
        WHEN pp.ITEMNMBR IS NOT NULL THEN 'Pooling_Only'
        ELSE 'Default'
    END AS Config_Status,
    GETDATE() AS Last_Updated
FROM dbo.ETB2_Config_Lead_Times lt WITH (NOLOCK)
FULL OUTER JOIN dbo.ETB2_Config_Part_Pooling pp WITH (NOLOCK)
    ON lt.ITEMNMBR = pp.ITEMNMBR
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR | Item number (PK) |
| Lead_Time_Days | INT | Lead time in days |
| Pooling_Classification | VARCHAR | Pooling strategy |
| Pooling_Multiplier | DECIMAL | Pooling multiplier |
| Config_Status | VARCHAR | Configuration state |
| Last_Updated | DATETIME | Timestamp |

---

## Demand Views (04)

### View 04: ETB2_Demand_Cleaned_Base

**Purpose:** Cleaned base demand excluding partial/invalid orders  
**Grain:** Order Line  
**Filters:**
- Excludes: 60.x/70.x order types, partial receives
- Priority: Remaining > Deductions > Expiry
- Window: ±21 days from GETDATE()

**Dependencies:** View 02B, external: `ETB_PAB_AUTO`, `Prosenthal_Vendor_Items`  

```sql
-- ============================================================================
-- VIEW 04: dbo.ETB2_Demand_Cleaned_Base
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Demand_Cleaned_Base
-- ============================================================================
-- Purpose: Cleaned base demand excluding partial/invalid orders
-- Grain: Order Line
--   - Excludes: 60.x/70.x order types, partial receives
--   - Priority: Remaining > Deductions > Expiry
--   - Window: ±21 days from GETDATE()
-- Dependencies:
--   - dbo.ETB_PAB_AUTO (external table)
--   - Prosenthal_Vendor_Items (external table)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Last Updated: 2026-01-28
-- ============================================================================

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
        TRY_CONVERT(DATE, [Date + Expiry]) AS Expiry_Date_Clean,
        pvi.ITEMDESC AS Item_Description,
        pvi.UOMSCHDL,
        'MAIN' AS Site  -- Default site for demand
    FROM dbo.ETB_PAB_AUTO pa WITH (NOLOCK)
    INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
      ON LTRIM(RTRIM(pa.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
    WHERE pa.ITEMNMBR NOT LIKE '60.%'
      AND pa.ITEMNMBR NOT LIKE '70.%'
      AND pa.STSDESCR <> 'Partially Received'
      AND pvi.Active = 'Yes'
),

CleanedDemand AS (
    SELECT
        ORDERNUMBER,
        ITEMNMBR,
        STSDESCR,
        Site,
        Item_Description,
        UOMSCHDL,
        Due_Date_Clean AS Due_Date,
        COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0) AS Remaining_Qty,
        COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0) AS Deductions_Qty,
        COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0) AS Expiry_Qty,
        Expiry_Date_Clean AS Expiry_Date,
        MRP_IssueDate,
        CASE
            WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0)
            WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0)
            WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0)
            ELSE 0.0
        END AS Base_Demand_Qty,
        CASE
            WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN 'Remaining'
            WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN 'Deductions'
            WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN 'Expiry'
            ELSE 'Zero'
        END AS Demand_Priority_Type,
        CASE
            WHEN Due_Date_Clean BETWEEN
                DATEADD(DAY, -21, CAST(GETDATE() AS DATE))
                AND DATEADD(DAY, 21, CAST(GETDATE() AS DATE))
            THEN 1 ELSE 0
        END AS Is_Within_Active_Planning_Window,
        CASE
            WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN 3
            WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN 3
            WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN 4
            ELSE 5
        END AS Event_Sort_Priority,
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
    WHERE Due_Date_Clean IS NOT NULL
      AND (COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0)) > 0
)

SELECT
    Clean_Order_Number AS Order_Number,
    ITEMNMBR AS Item_Number,
    COALESCE(ci.Item_Description, cd.Item_Description) AS Item_Description,
    ci.UOM_Schedule,
    Site,
    Due_Date,
    STSDESCR AS Status_Description,
    Base_Demand_Qty,
    Expiry_Qty,
    Expiry_Date,
    UOMSCHDL AS Unit_Of_Measure,
    Remaining_Qty,
    Deductions_Qty,
    Demand_Priority_Type,
    Is_Within_Active_Planning_Window,
    Event_Sort_Priority,
    MRP_IssueDate
FROM CleanedDemand cd
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON cd.ITEMNMBR = ci.Item_Number;

-- ============================================================================
-- END OF VIEW 04
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Order_Number | VARCHAR | Cleaned order number |
| Item_Number | VARCHAR | Item identifier |
| Item_Description | VARCHAR | Item description |
| UOM_Schedule | VARCHAR | UOM schedule |
| Site | VARCHAR | Site location |
| Due_Date | DATE | Due date |
| Status_Description | VARCHAR | Order status |
| Base_Demand_Qty | DECIMAL | Calculated demand quantity |
| Expiry_Qty | DECIMAL | Expiry quantity |
| Expiry_Date | DATE | Expiration date |
| Unit_Of_Measure | VARCHAR | UOM |
| Remaining_Qty | DECIMAL | Remaining quantity |
| Deductions_Qty | DECIMAL | Deductions quantity |
| Demand_Priority_Type | VARCHAR | Priority type |
| Is_Within_Active_Planning_Window | BIT | Planning window flag |
| Event_Sort_Priority | INT | Sort priority |
| MRP_IssueDate | DATETIME | MRP issue date |

---

## Inventory Views (05-07)

### View 05: ETB2_Inventory_WC_Batches

**Purpose:** Work Center batch inventory with FEFO ordering  
**Grain:** Batch/Lot  
**Dependencies:** External: `Prosenthal_INV_BIN_QTY_wQTYTYPE`, `EXT_BINTYPE`, `IV00101`  

```sql
-- ============================================================================
-- VIEW 05: dbo.ETB2_Inventory_WC_Batches
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Inventory_WC_Batches
-- ============================================================================
-- Purpose: Work Center batch inventory with FEFO ordering
-- Grain: Batch/Lot
-- Dependencies:
--   - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (external table)
--   - dbo.EXT_BINTYPE (external table)
--   - dbo.IV00101 (Item master - external table)
-- Last Updated: 2026-01-28
-- ============================================================================

WITH GlobalShelfLife AS (
    SELECT 180 AS Default_WC_Shelf_Life_Days
),

RawWCInventory AS (
    SELECT
        pib.Item_Number AS ITEMNMBR,
        pib.LOT_NUMBER,
        pib.Bin AS BIN,
        pib.SITE AS LOCNCODE,
        pib.QTY_Available,
        pib.DATERECD,
        pib.EXPNDATE
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
    WHERE pib.SITE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
),

ParsedInventory AS (
    SELECT
        ri.ITEMNMBR,
        ri.LOT_NUMBER,
        ri.BIN,
        ri.LOCNCODE,
        ri.QTY_Available,
        CAST(ri.DATERECD AS DATE) AS Receipt_Date,
        COALESCE(
            TRY_CONVERT(DATE, ri.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ri.DATERECD AS DATE))
        ) AS Expiry_Date,
        DATEDIFF(DAY, CAST(ri.DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        LEFT(ri.LOCNCODE, PATINDEX('%[-_]%', ri.LOCNCODE + '-') - 1) AS Client_ID,
        itm.ITEMDESC AS Item_Description,
        itm.UOMSCHDL AS Unit_Of_Measure
    FROM RawWCInventory ri
    CROSS JOIN GlobalShelfLife gsl
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
        ON LTRIM(RTRIM(ri.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
    WHERE COALESCE(
            TRY_CONVERT(DATE, ri.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ri.DATERECD AS DATE))
          ) >= CAST(GETDATE() AS DATE)  -- Exclude expired
)

-- ============================================================
-- FINAL OUTPUT: 14 columns, planner-optimized order
-- LEFT → RIGHT = IDENTIFY → LOCATE → QUANTIFY → TIME → DECIDE
-- ============================================================
SELECT
    -- IDENTIFY (what item?) - 3 columns
    ITEMNMBR                AS Item_Number,
    Item_Description,
    Unit_Of_Measure,

    -- LOCATE (where is it?) - 4 columns
    Client_ID,
    LOCNCODE                AS Site,
    BIN                     AS Bin,
    LOT_NUMBER              AS Lot,

    -- QUANTIFY (how much?) - 2 columns
    QTY_Available           AS Quantity,
    QTY_Available           AS Usable_Qty,  -- Same for WC (no degradation yet)

    -- TIME (when relevant?) - 3 columns
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,

    -- DECIDE (what action?) - 2 columns
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Expiry_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    'WC_BATCH'              AS Batch_Type

FROM ParsedInventory
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| Item_Description | VARCHAR | Item description |
| Unit_Of_Measure | VARCHAR | UOM |
| Client_ID | VARCHAR | Client identifier |
| Site | VARCHAR | Work center site |
| Bin | VARCHAR | Bin location |
| Lot | VARCHAR | Lot number |
| Quantity | DECIMAL | Available quantity |
| Usable_Qty | DECIMAL | Usable quantity |
| Receipt_Date | DATE | Receipt date |
| Expiry_Date | DATE | Expiration date |
| Days_To_Expiry | INT | Days until expiry |
| Use_Sequence | INT | FEFO sequence |
| Batch_Type | VARCHAR | 'WC_BATCH' |

---

### View 06: ETB2_Inventory_Quarantine_Restricted

**Purpose:** WFQ/RMQTY inventory with hold period management  
**Grain:** Item/Lot  
**Dependencies:** External: `IV00300`, `IV00101`  

```sql
-- ============================================================================
-- VIEW 06: dbo.ETB2_Inventory_Quarantine_Restricted
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Inventory_Quarantine_Restricted
-- ============================================================================
-- Purpose: WFQ/RMQTY inventory with hold period management
-- Grain: Item/Lot
-- Dependencies:
--   - dbo.IV00300 (Serial/Lot - external table)
--   - dbo.IV00101 (Item master - external table)
-- Last Updated: 2026-01-28
-- ============================================================================

WITH GlobalConfig AS (
    SELECT
        14 AS WFQ_Hold_Days,
        7 AS RMQTY_Hold_Days,
        90 AS Expiry_Filter_Days
),

RawWFQInventory AS (
    SELECT
        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'WF-Q'
      AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
),

RawRMQTYInventory AS (
    SELECT
        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'RMQTY'
      AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
),

ParsedWFQInventory AS (
    SELECT
        ITEMNMBR,
        MAX(ITEMDESC) AS Item_Description,
        MAX(UOMSCHDL) AS Unit_Of_Measure,
        LOCNCODE,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
        DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Release_Date,
        DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
        CASE
            WHEN DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
            THEN 1 ELSE 0
        END AS Is_Released,
        'WFQ' AS Hold_Type
    FROM RawWFQInventory
    GROUP BY ITEMNMBR, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
),

ParsedRMQTYInventory AS (
    SELECT
        ITEMNMBR,
        MAX(ITEMDESC) AS Item_Description,
        MAX(UOMSCHDL) AS Unit_Of_Measure,
        LOCNCODE,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
        DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Release_Date,
        DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
        CASE
            WHEN DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
            THEN 1 ELSE 0
        END AS Is_Released,
        'RMQTY' AS Hold_Type
    FROM RawRMQTYInventory
    GROUP BY ITEMNMBR, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
)

-- ============================================================
-- FINAL OUTPUT: 13 columns, planner-optimized order
-- ============================================================
SELECT
    -- IDENTIFY (what item?) - 3 columns
    ITEMNMBR                AS Item_Number,
    Item_Description,
    Unit_Of_Measure,

    -- LOCATE (where is it?) - 2 columns
    LOCNCODE                AS Site,
    Hold_Type,

    -- QUANTIFY (how much?) - 2 columns
    Available_Quantity      AS Quantity,
    Available_Quantity      AS Usable_Qty,

    -- TIME (when relevant?) - 4 columns
    Receipt_Date,
    Expiry_Date,
    Age_Days,
    Release_Date,
    DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,

    -- DECIDE (what action?) - 2 columns
    Is_Released             AS Can_Allocate,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence

FROM ParsedWFQInventory

UNION ALL

SELECT
    ITEMNMBR                AS Item_Number,
    Item_Description,
    Unit_Of_Measure,
    LOCNCODE                AS Site,
    Hold_Type,
    Available_Quantity      AS Quantity,
    Available_Quantity      AS Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    Age_Days,
    Release_Date,
    DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,
    Is_Released             AS Can_Allocate,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence

FROM ParsedRMQTYInventory
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| Item_Description | VARCHAR | Item description |
| Unit_Of_Measure | VARCHAR | UOM |
| Site | VARCHAR | Location code |
| Hold_Type | VARCHAR | 'WFQ' or 'RMQTY' |
| Quantity | DECIMAL | Available quantity |
| Usable_Qty | DECIMAL | Usable quantity |
| Receipt_Date | DATE | Receipt date |
| Expiry_Date | DATE | Expiration date |
| Age_Days | INT | Days since receipt |
| Release_Date | DATE | Hold release date |
| Days_To_Release | INT | Days until release |
| Can_Allocate | BIT | Allocation flag |
| Use_Sequence | INT | Priority sequence |

---

### View 07: ETB2_Inventory_Unified

**Purpose:** All eligible inventory consolidated (WC + released holds)  
**Grain:** Item/Lot  
**Dependencies:** Views 05, 06  

```sql
-- ============================================================================
-- VIEW 07: dbo.ETB2_Inventory_Unified (NEW)
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire SELECT...UNION...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Inventory_Unified
-- ============================================================================
-- Purpose: All eligible inventory consolidated (WC + released holds)
-- Grain: Item/Lot
-- Dependencies:
--   - dbo.ETB2_Inventory_WC_Batches (view 05)
--   - dbo.ETB2_Inventory_Quarantine_Restricted (view 06)
-- Last Updated: 2026-01-28
-- ============================================================================

-- WC Batches (always eligible)
SELECT
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    'WC' AS Site_Type,
    Quantity,
    Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    Days_To_Expiry,
    Use_Sequence,
    'AVAILABLE' AS Inventory_Type,
    1 AS Allocation_Priority  -- WC first
FROM dbo.ETB2_Inventory_WC_Batches WITH (NOLOCK)

UNION ALL

-- WFQ Batches (released only)
SELECT
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    Hold_Type AS Site_Type,
    Quantity,
    Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,
    Use_Sequence,
    'QUARANTINE_WFQ' AS Inventory_Type,
    2 AS Allocation_Priority  -- After WC
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'WFQ'
  AND Can_Allocate = 1

UNION ALL

-- RMQTY Batches (released only)
SELECT
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    Hold_Type AS Site_Type,
    Quantity,
    Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,
    Use_Sequence,
    'RESTRICTED_RMQTY' AS Inventory_Type,
    3 AS Allocation_Priority  -- After WFQ
FROM dbo.ETB2_Inventory_Quarantine_Restricted WITH (NOLOCK)
WHERE Hold_Type = 'RMQTY'
  AND Can_Allocate = 1
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| Item_Description | VARCHAR | Item description |
| Unit_Of_Measure | VARCHAR | UOM |
| Site | VARCHAR | Site location |
| Site_Type | VARCHAR | 'WC', 'WFQ', or 'RMQTY' |
| Quantity | DECIMAL | Total quantity |
| Usable_Qty | DECIMAL | Usable quantity |
| Receipt_Date | DATE | Receipt date |
| Expiry_Date | DATE | Expiration date |
| Days_To_Expiry | INT | Days until expiry |
| Use_Sequence | INT | Priority sequence |
| Inventory_Type | VARCHAR | Inventory category |
| Allocation_Priority | INT | Priority order (1=WC, 2=WFQ, 3=RMQTY) |

---

## Planning Views (08-10)

### View 08: ETB2_Planning_Net_Requirements

**Purpose:** Net requirements calculation from demand within planning window  
**Grain:** Item  
**Dependencies:** Views 04, 02B  

```sql
-- ============================================================================
-- VIEW 08: dbo.ETB2_Planning_Net_Requirements
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Planning_Net_Requirements
-- ============================================================================
-- Purpose: Net requirements calculation from demand within planning window
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Last Updated: 2026-01-28
-- ============================================================================

WITH Demand_Aggregated AS (
    SELECT
        Item_Number,
        SUM(COALESCE(TRY_CAST(Base_Demand_Qty AS NUMERIC(18, 4)), 0)) AS Total_Demand,
        COUNT(DISTINCT CAST(Due_Date AS DATE)) AS Demand_Days,
        COUNT(DISTINCT Order_Number) AS Order_Count,
        MIN(CAST(Due_Date AS DATE)) AS Earliest_Demand_Date,
        MAX(CAST(Due_Date AS DATE)) AS Latest_Demand_Date
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
    GROUP BY Item_Number
)
SELECT
    da.Item_Number,
    ci.Item_Description,
    ci.UOM_Schedule,
    CAST(da.Total_Demand AS NUMERIC(18, 4)) AS Net_Requirement_Qty,
    CAST(0 AS NUMERIC(18, 4)) AS Safety_Stock_Level,
    da.Demand_Days AS Days_Of_Supply,
    da.Order_Count,
    CASE
        WHEN da.Total_Demand = 0 THEN 'NONE'
        WHEN da.Total_Demand <= 100 THEN 'LOW'
        WHEN da.Total_Demand <= 500 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS Requirement_Priority,
    CASE
        WHEN da.Total_Demand = 0 THEN 'NO_DEMAND'
        WHEN da.Total_Demand <= 100 THEN 'LOW_PRIORITY'
        WHEN da.Total_Demand <= 500 THEN 'MEDIUM_PRIORITY'
        ELSE 'HIGH_PRIORITY'
    END AS Requirement_Status,
    da.Earliest_Demand_Date,
    da.Latest_Demand_Date
FROM Demand_Aggregated da
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON da.Item_Number = ci.Item_Number;

-- ============================================================================
-- END OF VIEW 08
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| Item_Description | VARCHAR | Item description |
| UOM_Schedule | VARCHAR | UOM schedule |
| Net_Requirement_Qty | NUMERIC | Total demand quantity |
| Safety_Stock_Level | NUMERIC | Safety stock (currently 0) |
| Days_Of_Supply | INT | Count of demand days |
| Order_Count | INT | Count of orders |
| Requirement_Priority | VARCHAR | NONE/LOW/MEDIUM/HIGH |
| Requirement_Status | VARCHAR | Status classification |
| Earliest_Demand_Date | DATE | First demand date |
| Latest_Demand_Date | DATE | Last demand date |

---

### View 09: ETB2_Planning_Stockout

**Purpose:** ATP balance and shortage risk analysis  
**Grain:** Item  
**Dependencies:** Views 07, 08, 02B  

```sql
-- ============================================================================
-- VIEW 09: dbo.ETB2_Planning_Stockout (NEW)
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Planning_Stockout
-- ============================================================================
-- Purpose: ATP balance and shortage risk analysis
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Planning_Net_Requirements (view 08)
--   - dbo.ETB2_Inventory_Unified (view 07)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Last Updated: 2026-01-28
-- ============================================================================

WITH

-- Net requirements from demand
NetRequirements AS (
    SELECT
        Item_Number,
        Net_Requirement_Qty,
        Order_Count,
        Requirement_Priority,
        Requirement_Status,
        Earliest_Demand_Date,
        Latest_Demand_Date
    FROM dbo.ETB2_Planning_Net_Requirements WITH (NOLOCK)
    WHERE Net_Requirement_Qty > 0
),

-- Available inventory (all eligible)
AvailableInventory AS (
    SELECT
        Item_Number,
        SUM(Usable_Qty) AS Total_Available
    FROM dbo.ETB2_Inventory_Unified WITH (NOLOCK)
    GROUP BY Item_Number
)

-- ============================================================
-- FINAL OUTPUT: 13 columns, planner-optimized order
-- ============================================================
SELECT
    -- IDENTIFY (what item?) - 4 columns
    COALESCE(nr.Item_Number, ai.Item_Number) AS Item_Number,
    ci.Item_Description,
    ci.UOM_Schedule AS Unit_Of_Measure_Schedule,
    
    -- QUANTIFY (the math) - 4 columns
    COALESCE(nr.Net_Requirement_Qty, 0) AS Net_Requirement,
    COALESCE(ai.Total_Available, 0) AS Total_Available,
    COALESCE(ai.Total_Available, 0) - COALESCE(nr.Net_Requirement_Qty, 0) AS ATP_Balance,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0)
        THEN COALESCE(nr.Net_Requirement_Qty, 0) - COALESCE(ai.Total_Available, 0)
        ELSE 0
    END AS Shortage_Quantity,

    -- DECIDE (risk assessment) - 5 columns
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 'CRITICAL'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 'HIGH'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Risk_Level,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) > 0 AND COALESCE(nr.Net_Requirement_Qty, 0) > 0
        THEN CAST(COALESCE(ai.Total_Available, 0) / NULLIF(COALESCE(nr.Net_Requirement_Qty, 0), 0) AS decimal(10,2))
        ELSE 999.99
    END AS Coverage_Ratio,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 1
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 2
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 3
        ELSE 4
    END AS Priority,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 'URGENT: No inventory'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 'EXPEDITE: Low coverage'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 'MONITOR: Partial coverage'
        ELSE 'OK: Adequate coverage'
    END AS Recommendation,
    nr.Requirement_Priority,
    nr.Requirement_Status

FROM NetRequirements nr
FULL OUTER JOIN AvailableInventory ai
    ON nr.Item_Number = ai.Item_Number
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON COALESCE(nr.Item_Number, ai.Item_Number) = ci.Item_Number

WHERE COALESCE(nr.Net_Requirement_Qty, 0) > 0
   OR COALESCE(ai.Total_Available, 0) > 0
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| Item_Description | VARCHAR | Item description |
| Unit_Of_Measure_Schedule | VARCHAR | UOM schedule |
| Net_Requirement | NUMERIC | Required quantity |
| Total_Available | NUMERIC | Available inventory |
| ATP_Balance | NUMERIC | Available to promise |
| Shortage_Quantity | NUMERIC | Shortage amount |
| Risk_Level | VARCHAR | CRITICAL/HIGH/MEDIUM/LOW |
| Coverage_Ratio | DECIMAL | Inventory coverage ratio |
| Priority | INT | Priority rank (1-4) |
| Recommendation | VARCHAR | Action recommendation |
| Requirement_Priority | VARCHAR | Demand priority |
| Requirement_Status | VARCHAR | Demand status |

---

### View 10: ETB2_Planning_Rebalancing_Opportunities

**Purpose:** Identify inventory rebalancing opportunities between work centers  
**Grain:** One row per item per surplus/deficit location pair  
**Dependencies:** Views 04, 07, external: `Prosenthal_INV_BIN_QTY_wQTYTYPE`  

```sql
-- ============================================================================
-- VIEW 10: dbo.ETB2_Planning_Rebalancing_Opportunities
-- Deploy Order: 10 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Identify inventory rebalancing opportunities between work centers
-- Grain: One row per item per surplus/deficit location pair
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Planning_Rebalancing_Opportunities
-- ============================================================================

SELECT 
    Surplus.Item_Number,
    Surplus.From_Work_Center,
    Surplus.Surplus_Qty,
    Deficit.To_Work_Center,
    Deficit.Deficit_Qty,
    CASE 
        WHEN Surplus.Surplus_Qty < Deficit.Deficit_Qty 
        THEN Surplus.Surplus_Qty 
        ELSE Deficit.Deficit_Qty 
    END AS Recommended_Transfer,
    Surplus.Surplus_Qty - Deficit.Deficit_Qty AS Net_Position,
    'TRANSFER' AS Rebalancing_Type,
    GETDATE() AS Identified_Date
FROM (
    SELECT 
        pib.ITEMNMBR AS Item_Number,
        pib.LOCNID AS From_Work_Center,
        SUM(COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0)) AS Surplus_Qty
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
    WHERE COALESCE(TRY_CAST(pib.QTY AS DECIMAL(18,4)), 0) > 0 
      AND pib.LOCNID LIKE 'WC[_-]%'
    GROUP BY pib.ITEMNMBR, pib.LOCNID
) Surplus
INNER JOIN (
    SELECT 
        d.Item_Number,
        i.Site AS To_Work_Center,
        SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS Deficit_Qty
    FROM dbo.ETB2_Demand_Cleaned_Base d WITH (NOLOCK)
    LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) ON d.Item_Number = i.Item_Number
    WHERE d.Is_Within_Active_Planning_Window = 1
    GROUP BY d.Item_Number, i.Site
    HAVING SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) - COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) > 0
) Deficit ON Surplus.Item_Number = Deficit.Item_Number;

-- ============================================================================
-- END OF VIEW 10
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| From_Work_Center | VARCHAR | Source location |
| Surplus_Qty | DECIMAL | Excess quantity |
| To_Work_Center | VARCHAR | Target location |
| Deficit_Qty | DECIMAL | Shortage quantity |
| Recommended_Transfer | DECIMAL | Suggested transfer amount |
| Net_Position | DECIMAL | Net surplus/deficit |
| Rebalancing_Type | VARCHAR | 'TRANSFER' |
| Identified_Date | DATETIME | Timestamp |

---

## Campaign Views (11-16)

### View 11: ETB2_Campaign_Normalized_Demand

**Purpose:** Campaign Consumption Units (CCU) - normalized demand per campaign  
**Grain:** One row per campaign per item  
**Dependencies:** View 04  

```sql
-- ============================================================================
-- VIEW 11: dbo.ETB2_Campaign_Normalized_Demand
-- Deploy Order: 11 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Campaign Consumption Units (CCU) - normalized demand per campaign
-- Grain: One row per campaign per item
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Normalized_Demand
-- ============================================================================

SELECT 
    d.Order_Number AS Campaign_ID,
    d.Item_Number,
    SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) AS Total_Campaign_Quantity,
    SUM(COALESCE(TRY_CAST(d.Base_Demand_Qty AS DECIMAL(18,4)), 0)) / 30.0 AS CCU,
    'DAILY' AS CCU_Unit,
    MIN(d.Due_Date) AS Peak_Period_Start,
    MAX(d.Due_Date) AS Peak_Period_End,
    DATEDIFF(DAY, MIN(d.Due_Date), MAX(d.Due_Date)) AS Campaign_Duration_Days,
    COUNT(DISTINCT d.Due_Date) AS Active_Days_Count
FROM dbo.ETB2_Demand_Cleaned_Base d WITH (NOLOCK)
WHERE d.Is_Within_Active_Planning_Window = 1
GROUP BY d.Order_Number, d.Item_Number;

-- ============================================================================
-- END OF VIEW 11
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Campaign_ID | VARCHAR | Campaign identifier |
| Item_Number | VARCHAR | Item identifier |
| Total_Campaign_Quantity | DECIMAL | Total demand |
| CCU | DECIMAL | Campaign Consumption Units (daily rate) |
| CCU_Unit | VARCHAR | 'DAILY' |
| Peak_Period_Start | DATE | Campaign start |
| Peak_Period_End | DATE | Campaign end |
| Campaign_Duration_Days | INT | Duration in days |
| Active_Days_Count | INT | Count of active days |

---

### View 12: ETB2_Campaign_Concurrency_Window

**Purpose:** Campaign Concurrency Window (CCW) - overlapping campaign periods  
**Grain:** One row per overlapping campaign pair  
**Dependencies:** View 11  

```sql
-- ============================================================================
-- VIEW 12: dbo.ETB2_Campaign_Concurrency_Window
-- Deploy Order: 12 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Campaign Concurrency Window (CCW) - overlapping campaign periods
-- Grain: One row per overlapping campaign pair
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Concurrency_Window
-- ============================================================================

SELECT 
    c1.Campaign_ID AS Campaign_A,
    c2.Campaign_ID AS Campaign_B,
    c1.Item_Number,
    CASE 
        WHEN c1.Peak_Period_Start > c2.Peak_Period_Start 
        THEN c1.Peak_Period_Start 
        ELSE c2.Peak_Period_Start 
    END AS Concurrency_Start,
    CASE 
        WHEN c1.Peak_Period_End < c2.Peak_Period_End 
        THEN c1.Peak_Period_End 
        ELSE c2.Peak_Period_End 
    END AS Concurrency_End,
    CASE 
        WHEN c1.Peak_Period_Start > c2.Peak_Period_Start 
             AND c1.Peak_Period_Start < c2.Peak_Period_End
        THEN DATEDIFF(DAY, c1.Peak_Period_Start, c2.Peak_Period_End)
        WHEN c2.Peak_Period_Start > c1.Peak_Period_Start 
             AND c2.Peak_Period_Start < c1.Peak_Period_End
        THEN DATEDIFF(DAY, c2.Peak_Period_Start, c1.Peak_Period_End)
        WHEN c1.Peak_Period_Start <= c2.Peak_Period_Start 
             AND c1.Peak_Period_End >= c2.Peak_Period_End
        THEN DATEDIFF(DAY, c2.Peak_Period_Start, c2.Peak_Period_End)
        WHEN c2.Peak_Period_Start <= c1.Peak_Period_Start 
             AND c2.Peak_Period_End >= c1.Peak_Period_End
        THEN DATEDIFF(DAY, c1.Peak_Period_Start, c1.Peak_Period_End)
        ELSE 0
    END AS Concurrency_Days,
    c1.CCU + c2.CCU AS Combined_CCU,
    (c1.CCU + c2.CCU) / NULLIF(c1.Campaign_Duration_Days, 0) AS Concurrency_Intensity
FROM dbo.ETB2_Campaign_Normalized_Demand c1 WITH (NOLOCK)
INNER JOIN dbo.ETB2_Campaign_Normalized_Demand c2 WITH (NOLOCK) 
    ON c1.Item_Number = c2.Item_Number
    AND c1.Campaign_ID < c2.Campaign_ID
WHERE 
    c1.Peak_Period_Start <= c2.Peak_Period_End
    AND c2.Peak_Period_Start <= c1.Peak_Period_End;

-- ============================================================================
-- END OF VIEW 12
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Campaign_A | VARCHAR | First campaign |
| Campaign_B | VARCHAR | Second campaign |
| Item_Number | VARCHAR | Item identifier |
| Concurrency_Start | DATE | Overlap start |
| Concurrency_End | DATE | Overlap end |
| Concurrency_Days | INT | Days of overlap |
| Combined_CCU | DECIMAL | Sum of CCUs |
| Concurrency_Intensity | DECIMAL | Intensity ratio |

---

### View 13: ETB2_Campaign_Collision_Buffer

**Purpose:** Calculate collision buffer requirements based on concurrency  
**Grain:** One row per campaign per item with collision risk  
**Dependencies:** Views 11, 12  

```sql
-- ============================================================================
-- VIEW 13: dbo.ETB2_Campaign_Collision_Buffer
-- Deploy Order: 13 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Calculate collision buffer requirements based on concurrency
-- Grain: One row per campaign per item with collision risk
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Collision_Buffer
-- ============================================================================

SELECT 
    n.Campaign_ID,
    n.Item_Number,
    n.Total_Campaign_Quantity,
    n.CCU,
    COALESCE(SUM(w.Combined_CCU) * 0.20, 0) AS collision_buffer_qty,
    n.Peak_Period_Start,
    n.Peak_Period_End,
    CASE 
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Collision_Risk_Level,
    COUNT(w.Campaign_B) AS Overlapping_Campaigns
FROM dbo.ETB2_Campaign_Normalized_Demand n WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Campaign_Concurrency_Window w WITH (NOLOCK) 
    ON (n.Campaign_ID = w.Campaign_A OR n.Campaign_ID = w.Campaign_B)
    AND n.Item_Number = w.Item_Number
GROUP BY n.Campaign_ID, n.Item_Number, n.Total_Campaign_Quantity, n.CCU,
         n.Peak_Period_Start, n.Peak_Period_End;

-- ============================================================================
-- END OF VIEW 13
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Campaign_ID | VARCHAR | Campaign identifier |
| Item_Number | VARCHAR | Item identifier |
| Total_Campaign_Quantity | DECIMAL | Total demand |
| CCU | DECIMAL | Consumption units |
| collision_buffer_qty | DECIMAL | 20% of combined CCU |
| Peak_Period_Start | DATE | Campaign start |
| Peak_Period_End | DATE | Campaign end |
| Collision_Risk_Level | VARCHAR | HIGH/MEDIUM/LOW |
| Overlapping_Campaigns | INT | Count of overlaps |

---

### View 14: ETB2_Campaign_Risk_Adequacy

**Purpose:** Inventory adequacy assessment vs collision buffer requirements  
**Grain:** One row per campaign per item  
**Dependencies:** Views 13, 17, 07  

```sql
-- ============================================================================
-- VIEW 14: dbo.ETB2_Campaign_Risk_Adequacy
-- Deploy Order: 14 of 17 (Deploy AFTER view 17)
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Inventory adequacy assessment vs collision buffer requirements
-- Grain: One row per campaign per item
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Risk_Adequacy
-- ============================================================================

SELECT 
    b.Item_Number,
    b.Campaign_ID,
    COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS Available_Inventory,
    SUM(b.collision_buffer_qty) AS Required_Buffer,
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS DECIMAL(10,2)) / SUM(b.collision_buffer_qty)
        ELSE 1.0
    END AS Adequacy_Score,
    CASE 
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS campaign_collision_risk,
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) / NULLIF(SUM(b.collision_buffer_qty), 0) * 30 AS INT)
        ELSE 30
    END AS Days_Buffer_Coverage,
    CASE 
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'URGENT_PROCUREMENT'
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) THEN 'SCHEDULE_PROCUREMENT'
        ELSE 'ADEQUATE'
    END AS Recommendation
FROM dbo.ETB2_Campaign_Collision_Buffer b WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) ON b.Item_Number = i.Item_Number
GROUP BY b.Item_Number, b.Campaign_ID;

-- ============================================================================
-- END OF VIEW 14
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| Campaign_ID | VARCHAR | Campaign identifier |
| Available_Inventory | DECIMAL | Current inventory |
| Required_Buffer | DECIMAL | Buffer requirement |
| Adequacy_Score | DECIMAL | Inventory/buffer ratio |
| campaign_collision_risk | VARCHAR | HIGH/MEDIUM/LOW |
| Days_Buffer_Coverage | INT | Days of coverage |
| Recommendation | VARCHAR | Action recommendation |

---

### View 15: ETB2_Campaign_Absorption_Capacity

**Purpose:** Executive KPI - campaign absorption capacity vs inventory  
**Grain:** One row per campaign item (aggregated)  
**Dependencies:** View 14  

```sql
-- ============================================================================
-- VIEW 15: dbo.ETB2_Campaign_Absorption_Capacity
-- Deploy Order: 15 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Executive KPI - campaign absorption capacity vs inventory
-- Grain: One row per campaign item (aggregated)
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Absorption_Capacity
-- ============================================================================

SELECT 
    r.Campaign_ID,
    SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) AS Total_Inventory,
    SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) AS Total_Buffer_Required,
    CASE 
        WHEN SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) > 0 
        THEN CAST(SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) AS DECIMAL(10,2)) / SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0))
        ELSE 1.0
    END AS Absorption_Ratio,
    CASE 
        WHEN SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) < SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) * 0.5 THEN 'CRITICAL'
        WHEN SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) < SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) THEN 'AT_RISK'
        WHEN SUM(COALESCE(TRY_CAST(r.Available_Inventory AS DECIMAL(18,4)), 0)) < SUM(COALESCE(TRY_CAST(r.Required_Buffer AS DECIMAL(18,4)), 0)) * 1.5 THEN 'HEALTHY'
        ELSE 'OVER_STOCKED'
    END AS Campaign_Health,
    COUNT(DISTINCT r.Item_Number) AS Items_In_Campaign,
    AVG(COALESCE(TRY_CAST(r.Adequacy_Score AS DECIMAL(10,2)), 0)) AS Avg_Adequacy,
    GETDATE() AS Calculated_Date
FROM dbo.ETB2_Campaign_Risk_Adequacy r WITH (NOLOCK)
GROUP BY r.Campaign_ID;

-- ============================================================================
-- END OF VIEW 15
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Campaign_ID | VARCHAR | Campaign identifier |
| Total_Inventory | DECIMAL | Sum of available inventory |
| Total_Buffer_Required | DECIMAL | Sum of buffer requirements |
| Absorption_Ratio | DECIMAL | Coverage ratio |
| Campaign_Health | VARCHAR | CRITICAL/AT_RISK/HEALTHY/OVER_STOCKED |
| Items_In_Campaign | INT | Count of items |
| Avg_Adequacy | DECIMAL | Average adequacy score |
| Calculated_Date | DATETIME | Timestamp |

---

### View 16: ETB2_Campaign_Model_Data_Gaps

**Purpose:** Data quality flags and confidence levels for model inputs  
**Grain:** One row per item from active configuration  
**Dependencies:** Views 03, 07, 04, 11  

```sql
-- ============================================================================
-- VIEW 16: dbo.ETB2_Campaign_Model_Data_Gaps
-- Deploy Order: 16 of 17
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Data quality flags and confidence levels for model inputs
-- Grain: One row per item from active configuration
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Model_Data_Gaps
-- ============================================================================

SELECT 
    c.ITEMNMBR AS Item_Number,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Lead_Time_Config,
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Pooling_Config,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN 1 ELSE 0 END AS Missing_Inventory_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END AS Missing_Demand_Data,
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Missing_Campaign_Data,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Campaign_Normalized_Demand) THEN 1 ELSE 0 END AS Total_Gap_Count,
    'LOW' AS data_confidence,
    CASE 
        WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 'Lead time uses system default (30 days);'
        ELSE ''
    END +
    CASE 
        WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 'Pooling classification uses system default (Dedicated);'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN ' No inventory data in work centers;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN ' No demand history;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Campaign_Normalized_Demand) THEN ' No campaign data.'
        ELSE ''
    END AS Gap_Description,
    CASE 
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base) THEN 1
        WHEN c.ITEMNMBR NOT IN (SELECT Item_Number FROM dbo.ETB2_Inventory_Unified) THEN 2
        ELSE 3
    END AS Remediation_Priority
FROM dbo.ETB2_Config_Active c WITH (NOLOCK);

-- ============================================================================
-- END OF VIEW 16
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Item_Number | VARCHAR | Item identifier |
| Missing_Lead_Time_Config | INT | Flag (1=missing) |
| Missing_Pooling_Config | INT | Flag (1=missing) |
| Missing_Inventory_Data | INT | Flag (1=missing) |
| Missing_Demand_Data | INT | Flag (1=missing) |
| Missing_Campaign_Data | INT | Flag (1=missing) |
| Total_Gap_Count | INT | Sum of all gaps |
| data_confidence | VARCHAR | 'LOW' |
| Gap_Description | VARCHAR | Description of gaps |
| Remediation_Priority | INT | Priority (1=highest) |

---

## Event Ledger (17)

### View 17: ETB2_PAB_EventLedger_v1

**Purpose:** Audit trail for PAB order changes - tracks all order modifications  
**Grain:** One row per order event (order created, modified, received, cancelled)  
**Dependencies:** View 04, external: `POP10100`, `POP10110`  

```sql
-- ============================================================================
-- VIEW 17: dbo.ETB2_PAB_EventLedger_v1
-- Deploy Order: 17 of 17 (Deploy BETWEEN 13 and 14)
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Audit trail for PAB order changes - tracks all order modifications
-- Grain: One row per order event (order created, modified, received, cancelled)
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_PAB_EventLedger_v1
-- ============================================================================

SELECT 
    LTRIM(RTRIM(p.PONUMBER)) AS Order_Number,
    LTRIM(RTRIM(p.VENDORID)) AS Vendor_ID,
    pd.ITEMNMBR AS Item_Number,
    pd.UOFM AS Unit_Of_Measure,
    COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) AS Ordered_Qty,
    COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) AS Received_Qty,
    COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) AS Remaining_Qty,
    CASE 
        WHEN COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) > 0 THEN 'RECEIVED'
        WHEN COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) = COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) THEN 'OPEN'
        WHEN COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) < COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) AND COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) > 0 THEN 'PARTIAL'
        ELSE 'PENDING'
    END AS Event_Type,
    TRY_CONVERT(DATE, p.DOCDATE) AS Order_Date,
    TRY_CONVERT(DATE, p.REQDATE) AS Required_Date,
    GETDATE() AS ETB2_Load_Date,
    ISNULL(i.ITEMDESC, '') AS Item_Description
FROM dbo.POP10100 p WITH (NOLOCK)
INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
LEFT JOIN dbo.IV00102 i WITH (NOLOCK) ON pd.ITEMNMBR = i.ITEMNMBR
WHERE pd.ITEMNMBR IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base)

UNION ALL

SELECT 
    LTRIM(RTRIM(pab.ORDERNUMBER)) AS Order_Number,
    '' AS Vendor_ID,
    LTRIM(RTRIM(pab.ITEMNMBR)) AS Item_Number,
    '' AS Unit_Of_Measure,
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pab.Running_Balance))) = 1 
        THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pab.Running_Balance)) AS DECIMAL(18,5)), 0)
        ELSE 0 
    END AS Ordered_Qty,
    0 AS Received_Qty,
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pab.Running_Balance))) = 1 
        THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pab.Running_Balance)) AS DECIMAL(18,5)), 0)
        ELSE 0 
    END AS Remaining_Qty,
    'DEMAND' AS Event_Type,
    TRY_CONVERT(DATE, pab.DUEDATE) AS Order_Date,
    TRY_CONVERT(DATE, pab.DUEDATE) AS Required_Date,
    GETDATE() AS ETB2_Load_Date,
    ISNULL(vi.ITEMDESC, '') AS Item_Description
FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
LEFT JOIN dbo.Prosenthal_Vendor_Items vi WITH (NOLOCK) ON LTRIM(RTRIM(pab.ITEMNMBR)) = LTRIM(RTRIM(vi.[Item Number]))
WHERE pab.STSDESCR <> 'Partially Received'
    AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '60.%'
    AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '70.%';

-- ============================================================================
-- END OF VIEW 17
-- ============================================================================
```

**Output Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Order_Number | VARCHAR | Order identifier |
| Vendor_ID | VARCHAR | Vendor code |
| Item_Number | VARCHAR | Item identifier |
| Unit_Of_Measure | VARCHAR | UOM |
| Ordered_Qty | DECIMAL | Original quantity |
| Received_Qty | DECIMAL | Received quantity |
| Remaining_Qty | DECIMAL | Remaining quantity |
| Event_Type | VARCHAR | RECEIVED/OPEN/PARTIAL/PENDING/DEMAND |
| Order_Date | DATE | Order date |
| Required_Date | DATE | Required delivery date |
| ETB2_Load_Date | DATETIME | Load timestamp |
| Item_Description | VARCHAR | Item description |

---

## External Dependencies

### Required External Tables

| Table | Database | Purpose |
|-------|----------|---------|
| dbo.IV00101 | MED | Item master |
| dbo.IV00102 | MED | Item quantity master |
| dbo.IV00300 | MED | Serial/Lot master |
| dbo.POP10100 | MED | PO header |
| dbo.POP10110 | MED | PO detail |
| dbo.ETB_PAB_AUTO | MED | PAB auto-generated orders |
| dbo.Prosenthal_Vendor_Items | MED | Vendor item reference |
| dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE | MED | Bin quantity with type |
| dbo.EXT_BINTYPE | MED | Bin type reference |

---

## Column Schema Reference

### Standardized Column Names

#### Item Identifier
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `ITEMNMBR` | `Item_Number` | Primary item identifier |
| `ITEMDESC` | `Item_Description` | Item description |
| `UOMSCHDL` | `Unit_Of_Measure` | Unit of measure |

#### Order Identifier
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `ORDERNUMBER` | `Order_Number` | PAB order number |
| `Clean_Order_Number` | `Order_Number` | Cleaned order number |
| `PONUMBER` | `Order_Number` | PO order number |
| `Order_Number` | `Campaign_ID` | Campaign order |

#### Date Fields
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `DUEDATE` | `Due_Date` | Original due date |
| `Due_Date_Clean` | `Due_Date` | Cleaned due date |
| `DOCDATE` | `Order_Date` | PO document date |
| `REQDATE` | `Required_Date` | Required delivery date |
| `RECEIPTDATE` | `Receipt_Date` | Inventory receipt date |
| `EXPNDATE` | `Expiry_Date` | Expiration date |

#### Location/Site Fields
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `LOCNID` | `Site` | Work center/location |
| `LOCNID` | `From_Work_Center` | Source WC |
| `LOCNID` | `To_Work_Center` | Target WC |
| `Hold_Type` | `Site_Type` | Quarantine hold type |

#### Quantity Fields
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `REMAINING` | `Remaining_Qty` | Remaining quantity |
| `DEDUCTIONS` | `Deductions_Qty` | Deductions quantity |
| `EXPIRY` | `Expiry_Qty` | Expiry quantity |
| `Base_Demand_Qty` | `Base_Demand_Qty` | Calculated demand |
| `QTY` | `Quantity` | Raw quantity |
| `QTY` | `Usable_Qty` | Available quantity |
| `QTYORDER` | `Ordered_Qty` | PO ordered quantity |
| `QTYRECEIVED` | `Received_Qty` | PO received quantity |
| `QTYREMGTD` | `Remaining_Qty` | PO remaining quantity |
| `Net_Requirement_Qty` | `Net_Requirement` | Net requirement |
| `Total_Available` | `Total_Available` | Available inventory |
| `ATP_Balance` | `ATP_Balance` | Available to promise |
| `Surplus_Qty` | `Surplus_Qty` | Surplus quantity |
| `Deficit_Qty` | `Deficit_Qty` | Deficit quantity |

#### Status Fields
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `STSDESCR` | `Status_Description` | PAB status |
| `Demand_Priority_Type` | `Demand_Priority_Type` | Priority type |
| `Requirement_Priority` | `Requirement_Priority` | Planning priority |
| `Requirement_Status` | `Requirement_Status` | Planning status |
| `Risk_Level` | `Risk_Level` | Stockout risk |
| `Collision_Risk_Level` | `Collision_Risk_Level` | Campaign collision risk |
| `Campaign_Health` | `Campaign_Health` | Campaign health status |

---

## Verification Query

After deploying all views, run this query to verify:

```sql
SELECT
    v.name AS View_Name,
    OBJECT_DEFINITION(OBJECT_ID(v.name)) AS View_Definition_Length
FROM sys.views v
WHERE v.name LIKE 'ETB2_%'
ORDER BY v.name;
```

Expected result: 17 views (01-17 plus 02B)

---

## Document Information

- **Generated:** 2026-01-29
- **Source:** refactored_views/ folder
- **Format:** Portable Markdown
- **Purpose:** Cross-model portability and documentation
- **Maintainer:** ETB2 Pipeline Team

---

*End of Document*
