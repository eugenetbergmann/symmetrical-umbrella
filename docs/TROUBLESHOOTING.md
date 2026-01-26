# ETB2 Troubleshooting Guide

## Common Errors and Solutions

### "Invalid column name 'XXX'"

**Error Example:**
```
Msg 207, Level 16, State 1, Line 5
Invalid column name 'ITEMNMBR'.
```

**Cause:** You're deploying out of order. The view references columns from views that don't exist yet.

**Solution:**
1. Check the file number you're trying to deploy
2. Verify all lower-numbered files have been deployed
3. Start over from file 01 if needed

---

### "Invalid object name 'dbo.ETB2_XXX'"

**Error Example:**
```
Msg 208, Level 16, State 1, Line 3
Invalid object name 'dbo.ETB2_Config_Lead_Times'.
```

**Cause:** A required dependency view or table hasn't been created.

**Solution:**
1. Check the file header for dependencies
2. Verify the required objects exist: `SELECT name FROM sys.objects WHERE name LIKE 'ETB2_%'`
3. Create missing dependencies first

---

### "Cannot find the object 'XXX' because it does not exist or you do not have permissions"

**Cause:** External source table doesn't exist or you lack permissions.

**Solution:**
1. Verify external tables exist: `SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES`
2. Check with DBA for missing source tables
3. See [reference/external_tables_required.md](reference/external_tables_required.md)

---

### Query Designer Issues

#### "Save button is grayed out"

**Cause:** Query hasn't been executed/validated.

**Solution:**
1. Click **Execute** (red ! icon) first
2. Verify results appear
3. Save should now be enabled

---

#### "Query Designer shows grid instead of SQL"

**Solution:**
1. Click **Query Designer** menu
2. Select **Pane** → **SQL**
3. The SQL text editor should appear

---

#### "No results returned but no error"

**Causes:**
- External source tables have no data
- Filters in query exclude all rows
- View logic error

**Solution:**
1. Test external table directly: `SELECT TOP 10 * FROM dbo.External_Table`
2. Check for WHERE clauses that might filter all rows
- Verify date ranges in query match available data

---

### Deployment Order Mistakes

#### "Deployed EventLedger first and got many errors"

**Solution:**
1. Delete the failed view: `DROP VIEW dbo.ETB2_PAB_EventLedger_v1`
2. Start over from file 01
3. Follow the correct order: 01→02→03→...→13→17→14→15→16

**Remember:** File 17 (EventLedger) deploys AFTER file 13 but BEFORE file 14!

---

### Performance Issues

#### "Query takes too long to execute"

**Solutions:**
1. Check external table indexes
2. Add WHERE clauses to limit data during testing
3. Consider breaking complex queries into parts
4. Verify statistics are up to date

---

#### "Memory error during execution"

**Cause:** Query returns too much data.

**Solution:**
1. Add TOP clause for testing: `SELECT TOP 100 * FROM ...`
2. Run during off-peak hours
3. Contact DBA for memory allocation

---

### Validation Failures

#### "Validation query returns 0 rows"

**Cause:** External source tables may be empty or query logic issue.

**Solution:**
1. Check external source data: `SELECT COUNT(*) FROM dbo.External_Table`
2. Verify column names match between sources and query
3. Check for NULL values that might affect counts

---

## Quick Diagnostic Queries

### Check all ETB2 objects exist

```sql
SELECT 
    name AS ObjectName,
    type_desc AS ObjectType,
    create_date AS CreatedDate
FROM sys.objects 
WHERE name LIKE 'ETB2_%'
ORDER BY name;
```

**Expected:** 17 objects (2 tables + 15 views)

### Check row counts for all views

```sql
-- Replace view names as needed
SELECT 'ETB2_Config_Active' AS ViewName, COUNT(*) AS RowCount FROM dbo.ETB2_Config_Active
UNION ALL SELECT 'ETB2_Demand_Cleaned_Base', COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
UNION ALL SELECT 'ETB2_Inventory_WC_Batches', COUNT(*) FROM dbo.ETB2_Inventory_WC_Batches
-- Add more as needed
```

### Check external table availability

```sql
SELECT 
    TABLE_SCHEMA + '.' + TABLE_NAME AS FullName,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%PAB%' 
    OR TABLE_NAME LIKE '%INV%' 
    OR TABLE_NAME LIKE '%POP%'
ORDER BY TABLE_NAME;
```

---

## Getting Help

1. **Check deployment order:** See [docs/DEPLOYMENT_ORDER.md](docs/DEPLOYMENT_ORDER.md)
2. **View definitions:** See [docs/VIEW_DEFINITIONS.md](docs/VIEW_DEFINITIONS.md)
3. **External tables:** See [reference/external_tables_required.md](reference/external_tables_required.md)
4. **Contact DBA** for missing permissions or source tables
