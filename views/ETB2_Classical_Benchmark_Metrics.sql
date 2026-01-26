-- ============================================================================
-- View: dbo.ETB2_Classical_Benchmark_Metrics
-- Purpose: Classical supply chain metrics for comparison only
-- WARNING: All metrics based on INVALID CONTINUOUS-DEMAND ASSUMPTIONS
-- Grain: Item
-- ============================================================================
-- NARRATIVE CONSISTENCY NOTES (Audit-Safe Explanation):
-- 
-- WHY DAILY USAGE IS INVALID:
-- CDMO operations are campaign-based, not continuous. Demand arrives in discrete
-- campaign batches with specific start/end dates. Averaging daily usage across
-- campaigns obscures the actual inventory consumption pattern and leads to
-- systematic underestimation of peak inventory requirements.
-- 
-- WHY Z-SCORES ARE REJECTED:
-- Classical safety stock formulas use Z-scores to buffer against demand variability.
-- This assumes demand follows a normal distribution and that variability can be
-- characterized by variance around a mean. Campaign demand violates both assumptions:
-- 1. Campaigns are discrete events, not continuous flow
-- 2. Variability is in campaign SIZE and TIMING, not around a mean
-- 3. The "mean" of zero-campaign days and high-campaign days is meaningless
-- 
-- WHY CAMPAIGN COLLISION IS THE CHOSEN RISK UNIT:
-- The ETB2 campaign model uses "collision buffer" instead of safety stock because:
-- 1. Collision buffer = CCU × CCW × pooling_multiplier
-- 2. CCU (Campaign Consumption Unit) = maximum campaign size per item
-- 3. CCW (Campaign Concurrency Window) = how many campaigns could overlap
-- 4. Pooling multiplier = adjustment for shared vs. dedicated inventory
-- This directly addresses the question: "Do we have enough inventory for the
-- maximum number of campaigns that could collide?" rather than "How many days
-- of average demand can we cover?"
-- 
-- These classical benchmarks are retained for:
-- - Historical comparison
-- - Transition documentation
-- - Auditors who need to see why continuous-demand logic was rejected
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Classical_Benchmark_Metrics AS

SELECT
    i.ITEMNMBR AS item_id,
    NULL AS EOQ_Continuous_demand_assumption_benchmark_only,
    NULL AS Classical_Safety_Stock_Continuous_demand_assumption_benchmark_only,
    NULL AS Reorder_Point_Continuous_demand_assumption_benchmark_only,
    'INVALID: These metrics assume continuous demand. Use campaign collision buffer instead.' AS benchmark_warning,
    'See ETB2_Campaign_Collision_Buffer for valid risk metric' AS recommended_alternative
FROM dbo.IV00101 i;