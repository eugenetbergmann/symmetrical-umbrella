# dbo.ETB2_PAB_EventLedger_v1 - Atomic Event Ledger View

## Overview

`dbo.ETB2_PAB_EventLedger_v1` is a SQL Server view that builds an **atomic event ledger** matching the PAB_AUTO pattern. It provides a complete, sequenced record of all inventory events (beginning balance, PO commitments, PO receipts, demand, and expiry) with running balance calculations.

## Key Features

### 1. **Atomic Event Structure**
Each row represents a single, indivisible inventory event with:
- Event type classification (BEGIN_BAL, PO_COMMITMENT, PO_RECEIPT, DEMAND, EXPIRY)
- Deterministic sort priority for consistent ordering
- Quantity impact (positive or negative)
- Running balance calculation

### 2. **Separate PO Commitment and Receipt Events**
- **PO_COMMITMENT**: Full ordered quantity minus cancellations (additive)
- **PO_RECEIPT**: Actual received quantity (additive)
- These are **NOT netted** - both events appear separately in the ledger
- Enables accurate tracking of supply pipeline

### 3. **60.x and 70.x Items INCLUDED**
- **CRITICAL**: 60.x and 70.x items are IN-PROCESS MATERIALS and are **INCLUDED** (not excluded)
- All active items from `Prosenthal_Vendor_Items` are processed
- Enables complete visibility into work-in-process inventory

### 4. **MO De-duplication**
- Manufacturing orders (MOs) with multiple lines for the same item but different due dates are de-duplicated
- Uses **earliest date** per item/MO combination
- Sums quantities across multiple dates
- Prevents double-counting of demand

### 5. **Running Balance Calculation**
- Cumulative sum of all event quantities (BEG_BAL + PO's + Deductions + Expiry)
- Partitioned by ITEMNMBR and Site
- Ordered by DUEDATE, SortPriority, ORDERNUMBER
- Enables point-in-time inventory visibility

## Event Structure

| Event Type | SortPriority | Column | Sign | Description |
|---|---|---|---|---|
| BEGIN_BAL | 1 | BEG_BAL | + | Starting inventory on hand |
| PO_COMMITMENT | 2 | [PO's] | + | Purchase order commitment (ordered - cancelled) |
| PO_RECEIPT | 2 | [PO's] | + | Purchase order receipt (actual received) |
| DEMAND | 3 | Deductions | - | Manufacturing demand (negative) |
| EXPIRY | 4 | Expiry | - | Expiring inventory (negative) |

## Column Definitions

### Identifiers
- **ORDERNUMBER**: PO number, MO number, or empty for beginning balance
- **ITEMNMBR**: Item number (trimmed)
- **ItemDescription**: Item description from Prosenthal_Vendor_Items
- **Site**: Location code (warehouse/site)

### Dates
- **DUEDATE**: Event date (1900-01-01 for beginning balance)
- **STSDESCR**: Status description (e.g., "Released", "Received", "Expiring")

### Quantities
- **BEG_BAL**: Beginning balance (only for BEGIN_BAL events)
- **[PO's]**: PO quantity (commitments and receipts)
- **Deductions**: Demand quantity (negative)
- **Expiry**: Expiry quantity (negative)

### Sequencing
- **SortPriority**: Event priority (1-4) for deterministic ordering
- **EventType**: Classification of event
- **EventSeq**: Row number within item/site partition
- **Running_Balance**: Cumulative balance at this event

### Attributes
- **UOMSCHDL**: Unit of measure schedule

## Business Rules

### 1. **60.x and 70.x Items**
- These are IN-PROCESS MATERIALS
- **MUST be INCLUDED** in the ledger (not excluded)
- Treated identically to other active items

### 2. **PO Commitments and Receipts**
- Treated as **separate additive events**
- NOT netted against each other
- Both contribute to running balance
- Enables tracking of:
  - Committed supply (what we ordered)
  - Received supply (what we got)
  - Pipeline visibility (committed - received = in-transit)

### 3. **MO De-duplication**
- If an MO has multiple lines for the same item with different due dates:
  - Use the **earliest date** as the event date
  - **Sum all quantities** for that item/MO combination
  - Results in one row per item/MO (not one per line)

### 4. **Demand Source**
- References `dbo.Rolyat_Cleaned_Base_Demand_1`
- Assumes this view filters out 'Partially Received' status
- Uses `Base_Demand` column (priority: Remaining > Deductions > Expiry)

### 5. **Expiry Events**
- Sourced from `dbo.Rolyat_Cleaned_Base_Demand_1` (Expiry column)
- Only included if:
  - Expiry quantity > 0
  - Expiry date is not NULL
  - Expiry date is within 6 months from today

### 6. **Date Ranges**
- **PO Commitments**: Last 12 months to next 18 months
- **PO Receipts**: Last 12 months to today
- **Demand**: All dates (from Rolyat_Cleaned_Base_Demand_1)
- **Expiry**: Next 6 months

## Dependencies

### Direct Dependencies
- **dbo.ETB_PAB_AUTO**: Source for beginning balance, demand, expiry
- **dbo.Rolyat_Cleaned_Base_Demand_1**: Demand and expiry reference
- **IV00102**: Inventory on hand (GP table)
- **POP10100**: PO lines (GP table)
- **POP10110**: PO headers (GP table)
- **POP10300**: PO receipts (GP table)
- **Prosenthal_Vendor_Items**: Item master with Active flag

### Indirect Dependencies
- **dbo.Rolyat_Config_Global**: Configuration (via Rolyat_Cleaned_Base_Demand_1)

## Usage Examples

### Example 1: View Complete Event Ledger for an Item
```sql
SELECT 
  DUEDATE,
  EventType,
  ORDERNUMBER,
  BEG_BAL,
  [PO's],
  Deductions,
  Expiry,
  Running_Balance
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE ITEMNMBR = 'YOUR_ITEM_NUMBER'
  AND Site = 'YOUR_SITE'
ORDER BY DUEDATE, SortPriority, ORDERNUMBER;
```

### Example 2: Check Running Balance at Specific Date
```sql
SELECT 
  ITEMNMBR,
  Site,
  MAX(Running_Balance) AS BalanceAsOf
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE DUEDATE <= '2026-02-01'
GROUP BY ITEMNMBR, Site;
```

### Example 3: Identify Stock-Out Risk
```sql
SELECT 
  ITEMNMBR,
  Site,
  DUEDATE,
  EventType,
  Running_Balance
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE Running_Balance < 0
ORDER BY ITEMNMBR, Site, DUEDATE;
```

### Example 4: Verify PO Separation
```sql
SELECT 
  EventType,
  COUNT(*) AS Count,
  SUM([PO's]) AS TotalQty
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType IN ('PO_COMMITMENT', 'PO_RECEIPT')
GROUP BY EventType;
```

### Example 5: Check 60.x and 70.x Items
```sql
SELECT DISTINCT ITEMNMBR
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE ITEMNMBR LIKE '60.%' OR ITEMNMBR LIKE '70.%'
ORDER BY ITEMNMBR;
```

## Performance Considerations

### Indexing Recommendations
- **IV00102**: Index on ITEMNMBR, LOCNCODE
- **POP10100**: Index on ITEMNMBR, REQDATE, PONUMBER
- **POP10300**: Index on ITEMNMBR, RECPTDATE, PONUMBER
- **Prosenthal_Vendor_Items**: Index on [Item Number], Active

### Query Optimization
- Filter by ITEMNMBR and Site early to reduce partition size
- Use DUEDATE range filters to limit event scope
- Consider materialized view if queried frequently

## Validation Queries

See `tests/ETB2_PAB_EventLedger_v1_validation.sql` for comprehensive test suite including:
- View structure validation
- Event type distribution
- 60.x and 70.x item verification
- PO commitment/receipt separation
- MO de-duplication validation
- Running balance calculation verification
- Expiry event validation
- Data quality checks

## Troubleshooting

### Issue: No 60.x or 70.x items appearing
- **Cause**: Items not marked as Active in Prosenthal_Vendor_Items
- **Solution**: Verify Active = 'Yes' for these items

### Issue: Running balance doesn't match expected value
- **Cause**: Events not ordered correctly or quantities miscalculated
- **Solution**: Check EventSeq ordering and verify event quantities in source tables

### Issue: MO quantities appear duplicated
- **Cause**: De-duplication not working (multiple rows per MO/item)
- **Solution**: Verify GROUP BY clause in DEMAND section includes all necessary columns

### Issue: PO commitments and receipts are netted
- **Cause**: Using wrong source or incorrect event type logic
- **Solution**: Verify PO_COMMITMENT and PO_RECEIPT are separate UNION ALL blocks

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-01-23 | Initial creation with atomic event ledger structure |

## Related Views

- **dbo.Rolyat_Cleaned_Base_Demand_1**: Base demand cleansing and calculation
- **dbo.Rolyat_Final_Ledger_3**: Final ledger with ATP/Forecast balances
- **dbo.Rolyat_PO_Detail**: PO supply aggregation
- **dbo.Rolyat_WC_Allocation_Effective_2**: Work center allocation

## Contact & Support

For questions or issues with this view, refer to the project documentation or contact the data engineering team.
