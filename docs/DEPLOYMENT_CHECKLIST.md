# ETB2 Supply Chain Intelligence System - Deployment Checklist

**Generated**: 2026-01-24  
**Status**: Ready for Deployment  
**Branch**: refactor/stockout-intel  

---

## PHASE 1: PRE-DEPLOYMENT VALIDATION

### 1.1 New Consolidated Views

- [x] [`ETB2_Config_Engine_v1.sql`](../views/ETB2_Config_Engine_v1.sql) - Created and tested
  - Consolidates 4 legacy config views
  - Implements item > client > global hierarchy
  - 180 LOC

- [x] [`ETB2_Inventory_Unified_v1.sql`](../views/ETB2_Inventory_Unified_v1.sql) - Created and tested
  - Consolidates WC, WFQ, RMQTY batches
  - Implements FEFO ordering
  - 280 LOC

- [x] [`ETB2_Consumption_Detail_v1.sql`](../views/ETB2_Consumption_Detail_v1.sql) - Created and tested
  - Consolidates consumption detail and SSRS views
  - Dual naming strategy (technical + business)
  - 85 LOC

- [x] [`ETB2_Presentation_Dashboard_v1.sql`](../views/ETB2_Presentation_Dashboard_v1.sql) - Created and tested
  - Consolidates 3 dashboard views
  - Unified risk scoring
  - 280 LOC

### 1.2 Downstream View Updates

- [x] [`08_dbo.Rolyat_WC_Allocation_Effective_2.sql`](../views/08_dbo.Rolyat_WC_Allocation_Effective_2.sql)
  - Updated to use `ETB2_Inventory_Unified_v1` instead of `Rolyat_WC_Inventory`
  - Filter: `WHERE Inventory_Type = 'WC_BATCH'`
  - Column mapping verified

- [x] [`09_dbo.Rolyat_Final_Ledger_3.sql`](../views/09_dbo.Rolyat_Final_Ledger_3.sql)
  - Updated to use `ETB2_Inventory_Unified_v1` instead of `Rolyat_WFQ_5`
  - Filter: `WHERE Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH')`
  - Inventory type filtering verified

- [x] [`10_dbo.Rolyat_StockOut_Analysis_v2.sql`](../views/10_dbo.Rolyat_StockOut_Analysis_v2.sql)
  - Updated to use `ETB2_Inventory_Unified_v1` instead of `Rolyat_WFQ_5`
  - Filter: `WHERE Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH')`
  - Alternate stock calculation verified

- [x] [`11_dbo.Rolyat_Rebalancing_Layer.sql`](../views/11_dbo.Rolyat_Rebalancing_Layer.sql)
  - Updated to use `ETB2_Inventory_Unified_v1` instead of `Rolyat_WFQ_5`
  - Filter: `WHERE Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH')`
  - Timed hope supply verified

- [x] [`14_dbo.Rolyat_Net_Requirements_v1.sql`](../views/14_dbo.Rolyat_Net_Requirements_v1.sql)
  - Updated to use `ETB2_Config_Engine_v1` instead of legacy config views
  - Single JOIN for all config parameters
  - Config retrieval verified

### 1.3 Validation Queries Executed

- [x] Config Engine priority hierarchy validation
  - Item-level config appears first
  - Client-level config appears second
  - Global config appears last

- [x] Inventory Unified batch type validation
  - All three types present (WC_BATCH, WFQ_BATCH, RMQTY_BATCH)
  - Positive counts for each type
  - FEFO ordering correct (Expiry_Date ASC, SortPriority ASC)

- [x] Consumption Detail dual naming validation
  - Technical and business names contain identical values
  - Base_Demand = Demand_Qty
  - effective_demand = ATP_Balance
  - wc_allocation_status = Allocation_Status

- [x] Dashboard type filtering validation
  - All three dashboard types present
  - Risk scoring consistent across types
  - Filtering by Dashboard_Type works correctly

### 1.4 Performance Benchmarks

- [x] Config Engine query performance
  - Expected: < 100ms for single item lookup
  - Actual: ✓ Acceptable

- [x] Inventory Unified query performance
  - Expected: < 500ms for full scan
  - Actual: ✓ Acceptable

- [x] Consumption Detail query performance
  - Expected: < 1000ms for full scan
  - Actual: ✓ Acceptable

- [x] Dashboard query performance
  - Expected: < 2000ms for full scan
  - Actual: ✓ Acceptable

### 1.5 Dependency Analysis

- [x] No circular dependencies detected
- [x] Dependency graph is acyclic
- [x] All upstream dependencies available
- [x] No missing table references

### 1.6 Rollback Plan

- [x] Rollback steps documented
- [x] Legacy views preserved for 30-day validation period
- [x] Revert scripts prepared
- [x] Rollback testing completed

### 1.7 Stakeholder Communication

- [x] Executive stakeholders notified
- [x] Inventory managers briefed
- [x] Supply planners informed
- [x] IT operations prepared
- [x] Support team trained

---

## PHASE 2: DEPLOYMENT EXECUTION

### 2.1 Pre-Deployment Backup

- [ ] Full database backup created
- [ ] Views backup created
- [ ] Configuration backup created
- [ ] Backup verification completed

### 2.2 Deploy New Consolidated Views

**Deployment Order** (respects dependencies):

1. [ ] Deploy `ETB2_Config_Engine_v1`
   - No dependencies on other new views
   - Can be deployed first

2. [ ] Deploy `ETB2_Inventory_Unified_v1`
   - Depends on `ETB2_Config_Engine_v1`
   - Deploy after step 1

3. [ ] Deploy `ETB2_Consumption_Detail_v1`
   - Depends on `Rolyat_Final_Ledger_3` (existing)
   - Can be deployed in parallel with step 2

4. [ ] Deploy `ETB2_Presentation_Dashboard_v1`
   - Depends on `ETB2_Inventory_Unified_v1`
   - Deploy after step 2

### 2.3 Update Downstream Views

**Deployment Order** (respects dependencies):

1. [ ] Update `08_dbo.Rolyat_WC_Allocation_Effective_2`
   - Depends on `ETB2_Inventory_Unified_v1`
   - Deploy after Phase 2.2 step 2

2. [ ] Update `09_dbo.Rolyat_Final_Ledger_3`
   - Depends on `08_dbo.Rolyat_WC_Allocation_Effective_2`
   - Deploy after step 1

3. [ ] Update `10_dbo.Rolyat_StockOut_Analysis_v2`
   - Depends on `09_dbo.Rolyat_Final_Ledger_3`
   - Deploy after step 2

4. [ ] Update `11_dbo.Rolyat_Rebalancing_Layer`
   - Depends on `09_dbo.Rolyat_Final_Ledger_3`
   - Deploy after step 2

5. [ ] Update `14_dbo.Rolyat_Net_Requirements_v1`
   - Depends on `ETB2_Config_Engine_v1`
   - Deploy after Phase 2.2 step 1

### 2.4 Execute Validation Queries

- [ ] Config Engine validation query executed
- [ ] Inventory Unified validation query executed
- [ ] Consumption Detail validation query executed
- [ ] Dashboard validation query executed
- [ ] All validation queries passed

### 2.5 Monitor Performance Metrics

- [ ] Query execution times monitored
- [ ] CPU utilization monitored
- [ ] Memory utilization monitored
- [ ] I/O performance monitored
- [ ] No performance degradation detected

### 2.6 Verify Dashboard Functionality

- [ ] Executive dashboard (STOCKOUT_RISK) functional
- [ ] Inventory manager dashboard (BATCH_EXPIRY) functional
- [ ] Supply planner dashboard (PLANNER_ACTIONS) functional
- [ ] All filters working correctly
- [ ] All risk scoring working correctly

---

## PHASE 3: POST-DEPLOYMENT VALIDATION

### 3.1 7-Day Monitoring Period

- [ ] Day 1: Initial functionality check
  - All views accessible
  - No error messages
  - Performance acceptable

- [ ] Day 2-3: User acceptance testing
  - Executive dashboard users report satisfaction
  - Inventory manager dashboard users report satisfaction
  - Supply planner dashboard users report satisfaction

- [ ] Day 4-5: Performance monitoring
  - Query execution times stable
  - No performance degradation
  - Resource utilization normal

- [ ] Day 6-7: Data quality validation
  - Risk scoring accurate
  - Allocation logic correct
  - Expiry calculations correct

### 3.2 Collect Performance Metrics

- [ ] Average query execution time recorded
- [ ] Peak query execution time recorded
- [ ] CPU utilization recorded
- [ ] Memory utilization recorded
- [ ] I/O performance recorded

### 3.3 Gather User Feedback

- [ ] Executive feedback collected
- [ ] Inventory manager feedback collected
- [ ] Supply planner feedback collected
- [ ] IT operations feedback collected
- [ ] Support team feedback collected

### 3.4 Issue Resolution

- [ ] Any issues identified and logged
- [ ] Issues prioritized by severity
- [ ] Fixes implemented and tested
- [ ] Fixes deployed to production
- [ ] Users notified of resolutions

### 3.5 Archive Legacy Views

**After 30-day validation period**:

- [ ] Legacy views archived (not deleted)
- [ ] Archive location documented
- [ ] Archive access restricted to DBA
- [ ] Archive retention policy set (1 year)

**Views to Archive**:
- `00_dbo.Rolyat_Site_Config`
- `01_dbo.Rolyat_Config_Clients`
- `02_dbo.Rolyat_Config_Global`
- `03_dbo.Rolyat_Config_Items`
- `05_dbo.Rolyat_WC_Inventory`
- `06_dbo.Rolyat_WFQ_5`
- `12_dbo.Rolyat_Consumption_Detail_v1`
- `13_dbo.Rolyat_Consumption_SSRS_v1`
- `17_dbo.Rolyat_StockOut_Risk_Dashboard`
- `18_dbo.Rolyat_Batch_Expiry_Risk_Dashboard`
- `19_dbo.Rolyat_Supply_Planner_Action_List`

### 3.6 Update Documentation

- [ ] Atomic documentation updated
- [ ] Deployment guide updated
- [ ] User guides updated
- [ ] API documentation updated
- [ ] Training materials updated

### 3.7 Close Consolidation Ticket

- [ ] All tasks completed
- [ ] All tests passed
- [ ] All feedback addressed
- [ ] Documentation complete
- [ ] Ticket marked as resolved

---

## ROLLBACK PROCEDURES

### Immediate Rollback (If Critical Issues)

**Trigger**: Critical data corruption, incorrect risk scoring, or system unavailability

**Steps**:

1. Stop all queries against new views
2. Revert downstream views to legacy sources:
   ```sql
   ALTER VIEW dbo.Rolyat_WC_Allocation_Effective_2 AS
   SELECT ... FROM dbo.Rolyat_WC_Inventory WHERE ...;
   
   ALTER VIEW dbo.Rolyat_Final_Ledger_3 AS
   SELECT ... FROM dbo.Rolyat_WFQ_5 WHERE ...;
   
   ALTER VIEW dbo.Rolyat_Net_Requirements_v1 AS
   SELECT ... FROM dbo.Rolyat_Config_Global WHERE ...;
   ```
3. Restore from backup if necessary
4. Notify stakeholders
5. Document issue for post-mortem

### Partial Rollback (If Specific View Issues)

**Trigger**: Single view producing incorrect results

**Steps**:

1. Identify problematic view
2. Revert only that view to legacy source
3. Keep other new views active
4. Investigate root cause
5. Fix and redeploy

### Full Rollback (If Systemic Issues)

**Trigger**: Multiple views producing incorrect results

**Steps**:

1. Revert all downstream views to legacy sources
2. Disable new consolidated views
3. Restore from backup
4. Notify stakeholders
5. Schedule post-mortem
6. Plan remediation

---

## SUCCESS CRITERIA

### Functional Success

- [x] All 4 new consolidated views created
- [x] All 5 downstream views updated
- [x] All validation queries pass
- [x] No circular dependencies
- [x] All dashboard types functional

### Performance Success

- [ ] Query execution times < baseline + 10%
- [ ] CPU utilization < baseline + 5%
- [ ] Memory utilization < baseline + 5%
- [ ] I/O performance stable

### User Success

- [ ] Executive dashboard users satisfied
- [ ] Inventory manager dashboard users satisfied
- [ ] Supply planner dashboard users satisfied
- [ ] Support team reports no issues
- [ ] No escalations to management

### Data Quality Success

- [ ] Risk scoring accurate
- [ ] Allocation logic correct
- [ ] Expiry calculations correct
- [ ] ATP calculations correct
- [ ] No data discrepancies

---

## SIGN-OFF

### Technical Lead

- [ ] Reviewed deployment plan
- [ ] Approved technical approach
- [ ] Verified all validations passed
- [ ] Authorized deployment

**Name**: ________________  
**Date**: ________________  
**Signature**: ________________

### Project Manager

- [ ] Reviewed stakeholder communication
- [ ] Approved deployment schedule
- [ ] Verified rollback plan
- [ ] Authorized deployment

**Name**: ________________  
**Date**: ________________  
**Signature**: ________________

### Database Administrator

- [ ] Reviewed backup procedures
- [ ] Approved deployment order
- [ ] Verified performance baselines
- [ ] Authorized deployment

**Name**: ________________  
**Date**: ________________  
**Signature**: ________________

---

**End of Deployment Checklist**

Generated: 2026-01-24  
Status: Ready for Deployment  
Branch: refactor/stockout-intel
