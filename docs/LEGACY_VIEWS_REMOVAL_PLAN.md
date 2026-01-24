# ETB2 Supply Chain Intelligence System - Legacy Views Removal Plan

**Generated**: 2026-01-24  
**Status**: Ready for Execution  
**Branch**: refactor/stockout-intel  

---

## OVERVIEW

This document outlines the plan for removing 11 legacy views that have been consolidated into 4 new unified views. The removal will occur in phases to ensure system stability and provide a rollback window.

---

## LEGACY VIEWS TO BE REMOVED

### Configuration Layer (4 views)

| View | LOC | Consolidated Into | Status |
|---|---|---|---|
| `00_dbo.Rolyat_Site_Config` | 32 | `ETB2_Config_Engine_v1` | ✓ Ready for removal |
| `01_dbo.Rolyat_Config_Clients` | 23 | `ETB2_Config_Engine_v1` | ✓ Ready for removal |
| `02_dbo.Rolyat_Config_Global` | 42 | `ETB2_Config_Engine_v1` | ✓ Ready for removal |
| `03_dbo.Rolyat_Config_Items` | 23 | `ETB2_Config_Engine_v1` | ✓ Ready for removal |

**Subtotal**: 4 views, 120 LOC

---

### Inventory Layer (2 views)

| View | LOC | Consolidated Into | Status |
|---|---|---|---|
| `05_dbo.Rolyat_WC_Inventory` | 124 | `ETB2_Inventory_Unified_v1` | ✓ Ready for removal |
| `06_dbo.Rolyat_WFQ_5` | 185 | `ETB2_Inventory_Unified_v1` | ✓ Ready for removal |

**Subtotal**: 2 views, 309 LOC

---

### Consumption Layer (2 views)

| View | LOC | Consolidated Into | Status |
|---|---|---|---|
| `12_dbo.Rolyat_Consumption_Detail_v1` | 76 | `ETB2_Consumption_Detail_v1` | ✓ Ready for removal |
| `13_dbo.Rolyat_Consumption_SSRS_v1` | 54 | `ETB2_Consumption_Detail_v1` | ✓ Ready for removal |

**Subtotal**: 2 views, 130 LOC

---

### Dashboard Layer (3 views)

| View | LOC | Consolidated Into | Status |
|---|---|---|---|
| `17_dbo.Rolyat_StockOut_Risk_Dashboard` | 85 | `ETB2_Presentation_Dashboard_v1` | ✓ Ready for removal |
| `18_dbo.Rolyat_Batch_Expiry_Risk_Dashboard` | 142 | `ETB2_Presentation_Dashboard_v1` | ✓ Ready for removal |
| `19_dbo.Rolyat_Supply_Planner_Action_List` | 108 | `ETB2_Presentation_Dashboard_v1` | ✓ Ready for removal |

**Subtotal**: 3 views, 335 LOC

---

**Total**: 11 views, 894 LOC to be removed

---

## REMOVAL PHASES

### PHASE 1: ARCHIVE (Days 1-30 Post-Deployment)

**Objective**: Keep legacy views active but mark them as deprecated

**Actions**:

1. **Add deprecation notices** to all legacy views:
   ```sql
   /*
   ===============================================================================
   DEPRECATED VIEW - DO NOT USE
   ===============================================================================
   This view has been consolidated into a new unified view.
   
   Consolidated Into: [New View Name]
   Deprecation Date: 2026-01-24
   Removal Date: 2026-02-24
   
   Please update your queries to use the new view instead.
   ===============================================================================
   */
   ```

2. **Create archive directory**:
   ```
   views/archive/
   ├── 00_dbo.Rolyat_Site_Config.sql
   ├── 01_dbo.Rolyat_Config_Clients.sql
   ├── 02_dbo.Rolyat_Config_Global.sql
   ├── 03_dbo.Rolyat_Config_Items.sql
   ├── 05_dbo.Rolyat_WC_Inventory.sql
   ├── 06_dbo.Rolyat_WFQ_5.sql
   ├── 12_dbo.Rolyat_Consumption_Detail_v1.sql
   ├── 13_dbo.Rolyat_Consumption_SSRS_v1.sql
   ├── 17_dbo.Rolyat_StockOut_Risk_Dashboard.sql
   ├── 18_dbo.Rolyat_Batch_Expiry_Risk_Dashboard.sql
   └── 19_dbo.Rolyat_Supply_Planner_Action_List.sql
   ```

3. **Document deprecation** in release notes:
   - List all deprecated views
   - Provide migration guide for each view
   - Include examples of new view usage

4. **Monitor usage** of legacy views:
   - Query SQL Server DMVs for view access
   - Identify any remaining dependencies
   - Notify teams of deprecated views

5. **Collect feedback**:
   - Monitor for issues with new views
   - Gather user feedback on consolidation
   - Document any problems for post-mortem

---

### PHASE 2: DISABLE (Days 31-60 Post-Deployment)

**Objective**: Disable legacy views to prevent accidental usage

**Actions**:

1. **Disable legacy views** (convert to disabled views):
   ```sql
   -- Disable view by replacing with error-raising view
   ALTER VIEW dbo.Rolyat_Site_Config
   AS
   SELECT 'ERROR: This view has been deprecated. Use ETB2_Config_Engine_v1 instead.' AS Error_Message
   WHERE 1 = 0;
   ```

2. **Create migration guide** for each view:
   - Old view name
   - New view name
   - Column mapping
   - Query examples
   - Migration steps

3. **Notify all users**:
   - Email notification of deprecation
   - Slack/Teams message
   - Documentation update
   - Training session

4. **Verify no dependencies**:
   - Query SQL Server for view references
   - Check stored procedures
   - Check reports
   - Check applications

---

### PHASE 3: REMOVE (Days 61+ Post-Deployment)

**Objective**: Remove legacy views from production

**Actions**:

1. **Final verification**:
   - Confirm no dependencies remain
   - Verify all users migrated to new views
   - Check for any outstanding issues

2. **Create backup** of legacy views:
   ```sql
   -- Backup legacy views to archive schema
   CREATE SCHEMA archive;
   
   -- Move views to archive schema
   -- (Note: Views cannot be moved, so copy definitions to archive)
   ```

3. **Drop legacy views**:
   ```sql
   DROP VIEW IF EXISTS dbo.Rolyat_Site_Config;
   DROP VIEW IF EXISTS dbo.Rolyat_Config_Clients;
   DROP VIEW IF EXISTS dbo.Rolyat_Config_Global;
   DROP VIEW IF EXISTS dbo.Rolyat_Config_Items;
   DROP VIEW IF EXISTS dbo.Rolyat_WC_Inventory;
   DROP VIEW IF EXISTS dbo.Rolyat_WFQ_5;
   DROP VIEW IF EXISTS dbo.Rolyat_Consumption_Detail_v1;
   DROP VIEW IF EXISTS dbo.Rolyat_Consumption_SSRS_v1;
   DROP VIEW IF EXISTS dbo.Rolyat_StockOut_Risk_Dashboard;
   DROP VIEW IF EXISTS dbo.Rolyat_Batch_Expiry_Risk_Dashboard;
   DROP VIEW IF EXISTS dbo.Rolyat_Supply_Planner_Action_List;
   ```

4. **Archive view definitions**:
   - Store in version control
   - Document removal date
   - Keep for 1 year for reference

5. **Update documentation**:
   - Remove references to legacy views
   - Update all guides
   - Update API documentation

---

## MIGRATION GUIDE

### Configuration Views Migration

#### View 00: Rolyat_Site_Config → ETB2_Config_Engine_v1

**Old Query**:
```sql
SELECT Site_ID, WFQ_Location, RMQTY_Location
FROM dbo.Rolyat_Site_Config
WHERE Site_ID = 'SITE001';
```

**New Query**:
```sql
SELECT Item_ID, Client_ID, WFQ_Location, RMQTY_Location
FROM dbo.ETB2_Config_Engine_v1
WHERE Client_ID = 'CLIENT001'
  AND Item_ID IS NULL  -- Global config
  AND Priority = 3;    -- Lowest priority (global)
```

---

#### View 01: Rolyat_Config_Clients → ETB2_Config_Engine_v1

**Old Query**:
```sql
SELECT Client_ID, WFQ_Hold_Days, RMQTY_Hold_Days
FROM dbo.Rolyat_Config_Clients
WHERE Client_ID = 'CLIENT001';
```

**New Query**:
```sql
SELECT Client_ID, WFQ_Hold_Period_Days, RMQTY_Hold_Period_Days
FROM dbo.ETB2_Config_Engine_v1
WHERE Client_ID = 'CLIENT001'
  AND Item_ID IS NULL  -- Client-level config
  AND Priority = 2;    -- Medium priority (client)
```

---

#### View 02: Rolyat_Config_Global → ETB2_Config_Engine_v1

**Old Query**:
```sql
SELECT Degradation_Tier_1, Degradation_Tier_2, Degradation_Tier_3, Degradation_Tier_4
FROM dbo.Rolyat_Config_Global;
```

**New Query**:
```sql
SELECT Degradation_Tier_1_Factor, Degradation_Tier_2_Factor, Degradation_Tier_3_Factor, Degradation_Tier_4_Factor
FROM dbo.ETB2_Config_Engine_v1
WHERE Item_ID IS NULL
  AND Client_ID IS NULL
  AND Priority = 3;  -- Global config
```

---

#### View 03: Rolyat_Config_Items → ETB2_Config_Engine_v1

**Old Query**:
```sql
SELECT Item_ID, Client_ID, Safety_Stock_Days
FROM dbo.Rolyat_Config_Items
WHERE Item_ID = 'ITEM001' AND Client_ID = 'CLIENT001';
```

**New Query**:
```sql
SELECT Item_ID, Client_ID, Safety_Stock_Level
FROM dbo.ETB2_Config_Engine_v1
WHERE Item_ID = 'ITEM001'
  AND Client_ID = 'CLIENT001'
  AND Priority = 1;  -- Item-level config (highest priority)
```

---

### Inventory Views Migration

#### View 05: Rolyat_WC_Inventory → ETB2_Inventory_Unified_v1

**Old Query**:
```sql
SELECT ITEMNMBR, Batch_ID, QTY_ON_HAND, Expiry_Date
FROM dbo.Rolyat_WC_Inventory
WHERE ITEMNMBR = 'ITEM001';
```

**New Query**:
```sql
SELECT ITEMNMBR, Batch_ID, QTY_ON_HAND, Expiry_Date
FROM dbo.ETB2_Inventory_Unified_v1
WHERE ITEMNMBR = 'ITEM001'
  AND Inventory_Type = 'WC_BATCH';
```

---

#### View 06: Rolyat_WFQ_5 → ETB2_Inventory_Unified_v1

**Old Query**:
```sql
SELECT ITEMNMBR, Batch_ID, QTY_ON_HAND, Expiry_Date, Is_Eligible_For_Release
FROM dbo.Rolyat_WFQ_5
WHERE ITEMNMBR = 'ITEM001';
```

**New Query**:
```sql
SELECT ITEMNMBR, Batch_ID, QTY_ON_HAND, Expiry_Date, Is_Eligible_For_Release
FROM dbo.ETB2_Inventory_Unified_v1
WHERE ITEMNMBR = 'ITEM001'
  AND Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH');
```

---

### Consumption Views Migration

#### View 12: Rolyat_Consumption_Detail_v1 → ETB2_Consumption_Detail_v1

**Old Query**:
```sql
SELECT ITEMNMBR, Base_Demand, effective_demand, wc_allocation_status
FROM dbo.Rolyat_Consumption_Detail_v1
WHERE ITEMNMBR = 'ITEM001';
```

**New Query**:
```sql
SELECT ITEMNMBR, Base_Demand, effective_demand, wc_allocation_status
FROM dbo.ETB2_Consumption_Detail_v1
WHERE ITEMNMBR = 'ITEM001';
```

**Note**: Column names remain the same; no migration needed

---

#### View 13: Rolyat_Consumption_SSRS_v1 → ETB2_Consumption_Detail_v1

**Old Query**:
```sql
SELECT ITEMNMBR, Demand_Qty, ATP_Balance, Allocation_Status
FROM dbo.Rolyat_Consumption_SSRS_v1
WHERE ITEMNMBR = 'ITEM001';
```

**New Query**:
```sql
SELECT ITEMNMBR, Demand_Qty, ATP_Balance, Allocation_Status
FROM dbo.ETB2_Consumption_Detail_v1
WHERE ITEMNMBR = 'ITEM001';
```

**Note**: Business-friendly column names available in new view

---

### Dashboard Views Migration

#### View 17: Rolyat_StockOut_Risk_Dashboard → ETB2_Presentation_Dashboard_v1

**Old Query**:
```sql
SELECT Item_Number, Risk_Level, Recommended_Action
FROM dbo.Rolyat_StockOut_Risk_Dashboard
WHERE Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK')
ORDER BY Action_Priority;
```

**New Query**:
```sql
SELECT Item_Number, Risk_Level, Recommended_Action
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
  AND Risk_Level IN ('CRITICAL_STOCKOUT', 'HIGH_RISK')
ORDER BY Action_Priority;
```

---

#### View 18: Rolyat_Batch_Expiry_Risk_Dashboard → ETB2_Presentation_Dashboard_v1

**Old Query**:
```sql
SELECT Item_Number, Batch_ID, Expiry_Risk_Tier, Recommended_Action
FROM dbo.Rolyat_Batch_Expiry_Risk_Dashboard
WHERE Expiry_Risk_Tier IN ('EXPIRED', 'CRITICAL', 'HIGH')
ORDER BY Days_Until_Expiry;
```

**New Query**:
```sql
SELECT Item_Number, Batch_ID, Expiry_Risk_Tier, Recommended_Action
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY'
  AND Expiry_Risk_Tier IN ('EXPIRED', 'CRITICAL', 'HIGH')
ORDER BY Days_Until_Expiry;
```

---

#### View 19: Rolyat_Supply_Planner_Action_List → ETB2_Presentation_Dashboard_v1

**Old Query**:
```sql
SELECT Action_Priority, Item_Number, Risk_Level, Recommended_Action
FROM dbo.Rolyat_Supply_Planner_Action_List
WHERE Action_Priority <= 2
ORDER BY Action_Priority;
```

**New Query**:
```sql
SELECT Action_Priority, Item_Number, Risk_Level, Recommended_Action
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS'
  AND Action_Priority <= 2
ORDER BY Action_Priority;
```

---

## DEPENDENCY VERIFICATION

### Step 1: Identify All Dependencies

```sql
-- Find all stored procedures that reference legacy views
SELECT DISTINCT
  OBJECT_NAME(sm.object_id) AS Procedure_Name,
  sm.definition
FROM sys.sql_modules sm
WHERE sm.definition LIKE '%Rolyat_Site_Config%'
   OR sm.definition LIKE '%Rolyat_Config_Clients%'
   OR sm.definition LIKE '%Rolyat_Config_Global%'
   OR sm.definition LIKE '%Rolyat_Config_Items%'
   OR sm.definition LIKE '%Rolyat_WC_Inventory%'
   OR sm.definition LIKE '%Rolyat_WFQ_5%'
   OR sm.definition LIKE '%Rolyat_Consumption_Detail_v1%'
   OR sm.definition LIKE '%Rolyat_Consumption_SSRS_v1%'
   OR sm.definition LIKE '%Rolyat_StockOut_Risk_Dashboard%'
   OR sm.definition LIKE '%Rolyat_Batch_Expiry_Risk_Dashboard%'
   OR sm.definition LIKE '%Rolyat_Supply_Planner_Action_List%';
```

### Step 2: Identify All Reports

- Check SSRS reports for legacy view references
- Check Power BI datasets for legacy view references
- Check Tableau data sources for legacy view references

### Step 3: Identify All Applications

- Check application code for legacy view references
- Check ETL processes for legacy view references
- Check scheduled jobs for legacy view references

---

## ROLLBACK PROCEDURE

If issues arise during removal phases:

### Phase 1 Rollback (Archive Phase)

**Action**: Remove deprecation notices from legacy views

```sql
-- Restore original view definitions
-- (Views remain active and functional)
```

**Impact**: Minimal - views continue to work as before

---

### Phase 2 Rollback (Disable Phase)

**Action**: Restore original view definitions

```sql
-- Restore original view definitions from backup
-- (Views become active again)
```

**Impact**: Users can resume using legacy views

---

### Phase 3 Rollback (Remove Phase)

**Action**: Recreate legacy views from archived definitions

```sql
-- Recreate all legacy views from archived SQL files
-- (Views become active again)
```

**Impact**: Full restoration of legacy views

---

## TIMELINE

| Phase | Start Date | End Date | Duration | Action |
|---|---|---|---|---|
| **Phase 1: Archive** | 2026-01-24 | 2026-02-24 | 30 days | Add deprecation notices, monitor usage |
| **Phase 2: Disable** | 2026-02-24 | 2026-03-26 | 30 days | Disable views, notify users |
| **Phase 3: Remove** | 2026-03-26 | 2026-03-31 | 5 days | Remove views, archive definitions |

---

## SIGN-OFF

### Database Administrator

- [ ] Reviewed removal plan
- [ ] Verified no critical dependencies
- [ ] Approved removal timeline
- [ ] Authorized removal

**Name**: ________________  
**Date**: ________________  
**Signature**: ________________

### Project Manager

- [ ] Reviewed stakeholder communication
- [ ] Approved removal timeline
- [ ] Verified user migration
- [ ] Authorized removal

**Name**: ________________  
**Date**: ________________  
**Signature**: ________________

---

**End of Legacy Views Removal Plan**

Generated: 2026-01-24  
Status: Ready for Execution  
Branch: refactor/stockout-intel
