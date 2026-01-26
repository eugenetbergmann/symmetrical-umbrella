# External Tables Required for ETB2 Views

This document lists all external (non-ETB2) tables that must exist before deploying the views.

---

## Core Demand Tables

### dbo.ETB_PAB_AUTO

**Used by:** File 04 (Demand_Cleaned_Base), File 17 (EventLedger)

**Description:** Primary demand source table containing sales orders and forecasts.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| ORD | VARCHAR(50) | Order number |
| QTYORDER | DECIMAL(18,2) | Ordered quantity |
| DUEDAT | DATE | Due date |
| POSTATUS | VARCHAR(20) | Post status |
| CUSTNMBR | VARCHAR(50) | Customer number |
| CITYCANCEL | VARCHAR(50) | Cancel reason |

**Sample Query:**
```sql
SELECT TOP 10 * FROM dbo.ETB_PAB_AUTO;
```

---

### dbo.Prosenthal_Vendor_Items

**Used by:** File 04 (Demand_Cleaned_Base)

**Description:** Vendor item mapping and master data.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| VENDORID | VARCHAR(50) | Vendor identifier |
| VENDNAME | VARCHAR(100) | Vendor name |
| VENDTYPE | VARCHAR(50) | Vendor type |

---

## Inventory Tables

### dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE

**Used by:** File 05 (Inventory_WC_Batches)

**Description:** Inventory quantities by bin location with quantity types.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| LOCNID | VARCHAR(50) | Location ID |
| BIN | VARCHAR(50) | Bin location |
| QTY | DECIMAL(18,2) | Quantity |
| QTYTYPE | VARCHAR(50) | Quantity type |
| EXTDATE | DATE | Expiration date |
| RCRDTYPE | INT | Record type |

---

### dbo.EXT_BINTYPE

**Used by:** File 05 (Inventory_WC_Batches)

**Description:** Extended bin type definitions.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| BINTYPE | VARCHAR(50) | Bin type code |
| BINTYPEDESC | VARCHAR(100) | Description |
| FEFO_FLAG | INT | FEFO enabled flag |

---

### dbo.IV00300

**Used by:** File 06 (Inventory_Quarantine_Restricted)

**Description:** Inventory quantity master with lot/serial information.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| LOCNID | VARCHAR(50) | Location ID |
| BIN | VARCHAR(50) | Bin location |
| QTYOH | DECIMAL(18,2) | Quantity on hand |
| QTYRCTD | DECIMAL(18,2) | Quantity received |
| QTYCOMTD | DECIMAL(18,2) | Quantity committed |
| QTYSOLD | DECIMAL(18,2) | Quantity sold |

---

### dbo.IV00101

**Used by:** File 06 (Inventory_Quarantine_Restricted)

**Description:** Item master table.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| ITEMDESC | VARCHAR(100) | Item description |
| ITEMTYPE | INT | Item type |
| STNDCOST | DECIMAL(18,2) | Standard cost |

---

### dbo.IV00102

**Used by:** File 17 (EventLedger)

**Description:** Inventory valuation and transaction history.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| TRXQTY | DECIMAL(18,2) | Transaction quantity |
| TRXDT | DATE | Transaction date |
| TRXTYPE | INT | Transaction type |
| DOCNUMBR | VARCHAR(50) | Document number |

---

## Purchase Order Tables

### dbo.POP10100

**Used by:** File 17 (EventLedger)

**Description:** Purchase order header.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| PONUMBER | VARCHAR(50) | Purchase order number |
| VENDORID | VARCHAR(50) | Vendor ID |
| DOCDATE | DATE | Document date |
| SUBTOTAL | DECIMAL(18,2) | Subtotal |
| DOCSTATUS | VARCHAR(20) | Document status |

---

### dbo.POP10110

**Used by:** File 17 (EventLedger)

**Description:** Purchase order line details.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| PONUMBER | VARCHAR(50) | Purchase order number |
| ORD | INT | Line number |
| ITEMNMBR | VARCHAR(50) | Part number |
| QTYORDER | DECIMAL(18,2) | Ordered quantity |
| QTYSHPPD | DECIMAL(18,2) | Shipped quantity |
| UNITPRCE | DECIMAL(18,2) | Unit price |

---

### dbo.POP10300

**Used by:** File 17 (EventLedger)

**Description:** Purchase order receipt history.

**Required Columns:**
| Column | Type | Description |
|--------|------|-------------|
| PONUMBER | VARCHAR(50) | Purchase order number |
| POPRCTNM | VARCHAR(50) | Receipt number |
| ITEMNMBR | VARCHAR(50) | Part number |
| QTYSHPPD | DECIMAL(18,2) | Quantity shipped/received |
| RCVDATE | DATE | Receipt date |

---

## Summary: Tables by File

| File | View | External Tables Required |
|------|------|--------------------------|
| 04 | Demand_Cleaned_Base | ETB_PAB_AUTO, Prosenthal_Vendor_Items |
| 05 | Inventory_WC_Batches | Prosenthal_INV_BIN_QTY_wQTYTYPE, EXT_BINTYPE |
| 06 | Inventory_Quarantine_Restricted | IV00300, IV00101 |
| 07 | Inventory_Unified_Eligible | (all from 05, 06) |
| 17 | PAB_EventLedger_v1 | ETB_PAB_AUTO, IV00102, POP10100, POP10110, POP10300 |

---

## Verification Checklist

Before deploying views, verify all external tables exist:

```sql
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN (
    'ETB_PAB_AUTO',
    'Prosenthal_Vendor_Items',
    'Prosenthal_INV_BIN_QTY_wQTYTYPE',
    'EXT_BINTYPE',
    'IV00300',
    'IV00101',
    'IV00102',
    'POP10100',
    'POP10110',
    'POP10300'
);
```

**Expected Result:** All 10 tables should be listed.

If any tables are missing, contact your DBA or system administrator.
