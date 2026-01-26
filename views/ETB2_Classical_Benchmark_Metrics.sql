-- ============================================================================
-- View: dbo.ETB2_Classical_Benchmark_Metrics
-- Purpose: Classical supply chain metrics for comparison only
-- WARNING: All metrics based on invalid continuous-demand assumptions
-- Grain: Item
-- Notes:
--   - EOQ: Economic Order Quantity (sqrt(2*annual_demand*ordering_cost/holding_cost))
--   - Classical Safety Stock: Z-score based buffer
--   - Reorder Point: Lead time demand + safety stock
--   - All values are NULL because continuous-demand data is unavailable/rejected
--   - These are benchmarks only; DO NOT use for planning decisions
-- Dependencies: None (placeholders)
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Classical_Benchmark_Metrics AS

SELECT
    i.ITEMNMBR AS item_id,
    NULL AS EOQ_Continuous_demand_assumption_benchmark_only,
    NULL AS Classical_Safety_Stock_Continuous_demand_assumption_benchmark_only,
    NULL AS Reorder_Point_Continuous_demand_assumption_benchmark_only,
    'These metrics assume continuous demand and are invalid for campaign-based CDMO operations' AS benchmark_warning
FROM dbo.IV00101 i;