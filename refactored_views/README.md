# ETB2 Pipeline - Refactored Views for SSMS Deployment

**Status:** ✅ PRODUCTION READY
**Last Updated:** 2026-01-28
**Database:** MED (usca2w100968\gpprod)

---

## Quick Start

1. **Open any view file** (e.g., `01_ETB2_Config_Lead_Times.sql`)
2. **Copy the entire SQL statement**
3. **Paste into SSMS** (New Query window)
4. **Execute (F5)** to test
5. **Right-click → Create View**
6. **Save as** `dbo.ViewName`

**That's it!** No deployment scripts needed. Just copy/paste from git.

---

## Deployment Order (Critical)

Views must be deployed in this order:

```
1. 01_ETB2_Config_Lead_Times.sql          (No dependencies)
2. 02_ETB2_Config_Part_Pooling.sql        (No dependencies)
3. 03_ETB2_Config_Active.sql              (Depends on 01, 02)
4. 04_ETB2_Demand_Cleaned_Base.sql        (Depends on external tables)
5. 05_ETB2_Inventory_WC_Batches.sql       (Depends on external tables)
6. 06_ETB2_Inventory_Quarantine_Restricted.sql (Depends on external tables)
7. 07_ETB2_Inventory_Unified.sql          (NEW - Depends on 05, 06)
8. 08_ETB2_Planning_Net_Requirements.sql   (Depends on 04)
9. 09_ETB2_Planning_Stockout.sql          (NEW - Depends on 07, 08)
```

**Total Deployment Time:** ~30 minutes (3-4 minutes per view)

---

## What's Included

### Refactored Views (9 total)

| # | View Name | Status | Description |
|---|-----------|---------|-------------|
| 01 | ETB2_Config_Lead_Times | ✅ Refactored | Lead time configuration (30-day default) |
| 02 | ETB2_Config_Part_Pooling | ✅ Refactored | Pooling classification (Dedicated default) |
| 03 | ETB2_Config_Active | ✅ Refactored | Unified configuration layer |
| 04 | ETB2_Demand_Cleaned_Base | ✅ Refactored | Cleaned demand (excludes partial/invalid) |
| 05 | ETB2_Inventory_WC_Batches | ✅ Refactored | WC batch inventory with FEFO |
| 06 | ETB2_Inventory_Quarantine_Restricted | ✅ Refactored | WFQ/RMQTY inventory with holds |
| 07 | ETB2_Inventory_Unified | ✅ NEW | All eligible inventory consolidated |
| 08 | ETB2_Planning_Net_Requirements | ✅ Refactored | Net requirements from demand |
| 09 | ETB2_Planning_Stockout | ✅ NEW | ATP balance and stockout risk |

### Issues Fixed

- ✅ **NOLOCK hints** added to all external table references
- ✅ **Type safety** (TRY_CAST/TRY_CONVERT) added to all conversions
- ✅ **NULL safety** (COALESCE) added to all aggregations
- ✅ **CREATE VIEW statements** removed (clean SELECT/WITH only)
- ✅ **Deployment headers** added to all views
- ✅ **ETB3 references** verified (none found - already correct)

---

## File Format

Each view file contains:

1. **Deployment Instructions Header** (lines 1-15)
   - View name and purpose
   - Step-by-step deployment instructions
   - Dependencies list
   - Last updated date

2. **Clean SQL Statement** (lines 16+)
   - SELECT or WITH...SELECT statement
   - NO CREATE VIEW statement
   - Proper indentation (4 spaces)
   - NOLOCK hints on all external table references
   - Type-safe casting (TRY_CAST/TRY_CONVERT)
   - NULL-safe aggregations (COALESCE)

---

## Verification

After deploying all views, run this query to verify:

```sql
SELECT
    v.name AS View_Name,
    OBJECT_DEFINITION(OBJECT_ID(v.name)) AS View_Definition_Length
FROM sys.views v
WHERE v.name LIKE 'ETB2_%'
ORDER BY v.name;
```

**Expected:** All 9 views listed

---

## Documentation

- **[DEPLOYMENT_REPORT.md](DEPLOYMENT_REPORT.md)** - Comprehensive deployment guide with:
  - View-by-view changes
  - Critical fixes section
  - New views details
  - Verification queries
  - Troubleshooting guide

---

## Git Commit

When ready to commit:

```bash
git add refactored_views/
git commit -m "ETB2 Pipeline: Fix all issues for SSMS deployment

- Add NOLOCK hints to all external table references
- Add type safety (TRY_CAST/TRY_CONVERT) to all conversions
- Add NULL safety (COALESCE) to all aggregations
- Remove CREATE VIEW statements (clean SELECT/WITH only)
- Create ETB2_Inventory_Unified view (combines WC + quarantine)
- Create ETB2_Planning_Stockout view (supply/demand analysis)
- Add deployment instruction headers to all views
- All views ready for copy/paste from git to SSMS

Total: 9 views refactored, 2 new views created
Status: Production Ready"
```

---

## Support

For detailed deployment instructions, see [DEPLOYMENT_REPORT.md](DEPLOYMENT_REPORT.md).

---

**Status:** ✅ PRODUCTION READY
**Total Views:** 9 (7 refactored + 2 new)
**Deployment Method:** Copy/Paste from Git to SSMS
