# ETB2 Campaign-Based Risk Model: Conceptual Foundation

**Date:** 2026-01-26  
**Purpose:** Explain the shift from daily-usage safety stock to campaign collision buffers  
**Audience:** Executives, Planners, Analysts  

---

## Executive Summary

ETB2 analytics has been extended with a campaign-based risk model that replaces traditional safety stock calculations. This model treats demand as contracted, campaign-based, and non-continuous, focusing on campaign collision as the primary risk unit rather than daily usage averages.

The model surfaces data gaps explicitly and provides conservative defaults to protect against false precision in planning decisions.

---

## Why Daily Usage Was Rejected

### The Assumption
Traditional supply chain models assume continuous demand that can be averaged into "daily usage" rates. Safety stock is then calculated as Z-score multiples of this daily rate, adjusted for lead time variability.

### Why It Doesn't Apply Here
- **Novel-Modality CDMO Context:** Demand arrives in discrete campaigns, not continuous flows. Averaging campaign peaks and troughs into daily rates obscures the true risk profile.
- **Contracted Nature:** Orders are committed in advance for specific production runs, not random daily pulls.
- **Non-Continuous Reality:** Extended periods of zero demand followed by sudden campaign spikes invalidate daily averaging.
- **False Precision:** Daily rates imply predictability that doesn't exist in campaign-based operations, leading to over- or under-stocking.

### Impact
Using daily averages for buffer calculations would either:
- Over-buffer during troughs (wasting capital)
- Under-buffer during peaks (risking campaign delays)

---

## Why Z-Scores Were Abandoned

### The Assumption
Z-score safety stock assumes normally distributed demand variability around a mean daily usage rate. The formula `Safety Stock = Z × σ × √(Lead Time)` relies on:
- Stable mean demand
- Known standard deviation
- Normal distribution of errors

### Why It Doesn't Apply Here
- **Campaign Overlap Risk:** The relevant risk is not daily variability, but how many campaigns might collide within a lead time window.
- **Non-Normal Demand:** Campaign demand is lumpy and scheduled, not randomly distributed.
- **Lead Time Horizons:** Z-scores don't account for concurrent campaign execution within supplier lead times.
- **Pooling Effects:** Part sharing across campaigns changes risk dynamics in ways Z-scores can't capture.

### Impact
Z-score buffers would provide mathematically precise but practically irrelevant numbers, giving planners false confidence in continuous-demand assumptions.

---

## Why Campaign Collision Is the Correct Risk Unit

### The Correct Assumption
Demand occurs in campaigns with defined start/end dates and consumption quantities. Risk arises when multiple campaigns require the same parts simultaneously, especially during supplier lead times.

### Key Concepts
- **Campaign Consumption Unit (CCU):** Total quantity needed per campaign for an item
- **Campaign Concurrency Window (CCW):** How many campaigns can overlap within lead time
- **Collision Buffer:** CCU × CCW × Pooling Multiplier
- **Absorbable Campaigns:** How many campaigns current inventory can support

### Why This Fits
- **Matches Business Reality:** Campaigns are the planning unit for novel-modality CDMOs
- **Accounts for Overlap:** Recognizes that concurrent campaigns create multiplicative demand spikes
- **Incorporates Pooling:** Adjusts for whether parts are dedicated or shared across products
- **Lead Time Aware:** Considers supplier constraints in risk calculation
- **Executive Relevant:** Provides clear "how many campaigns can we absorb?" metrics

### Impact
This model protects against campaign delays by ensuring buffers match actual risk drivers, not statistical artifacts.

---

## Model Implementation Notes

### Data Quality Handling
- Missing campaign IDs/dates flagged as LOW CONFIDENCE
- Conservative defaults used (e.g., CCW=1, Dedicated pooling)
- All assumptions documented in view comments
- Gap reports provided for data stewards

### Benchmark Preservation
Classical metrics (EOQ, safety stock, reorder points) are computed as NULL placeholders with explicit warnings. They exist for comparison only and must not influence planning decisions.

### No Existing Logic Modified
All new views are additive; existing ETB2 views remain unchanged to preserve current operations.

---

## Next Steps

1. **Data Integration:** Connect to campaign management system for actual campaign IDs, start/end dates, and groupings
2. **Lead Time Updates:** Populate ETB2_Config_Lead_Times with actual supplier data
3. **Pooling Classification:** Work with manufacturing engineering to classify parts
4. **Model Validation:** Monitor campaign absorption metrics against actual performance
5. **Executive Adoption:** Use absorbable_campaigns as primary capacity KPI

This foundation provides a risk model suited to campaign-based operations while maintaining backward compatibility and data quality transparency.