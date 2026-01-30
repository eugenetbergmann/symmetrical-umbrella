-- ============================================================================
-- VIEW 16: dbo.ETB2_Campaign_Model_Data_Gaps (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Data quality flags and confidence levels for model inputs
-- Grain: One row per item from active configuration
-- Dependencies:
--   - dbo.ETB2_Config_Active (view 03)
--   - dbo.ETB2_Inventory_Unified (view 07)
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
--   - dbo.ETB2_Campaign_Normalized_Demand (view 11)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct linked from demand base
--   - Is_Suppressed flag
-- Last Updated: 2026-01-30
-- ============================================================================

SELECT 
    -- Context columns preserved
    c.client,
    c.contract,
    c.run,
    
    c.ITEMNMBR AS Item_Number,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Lead_Time_Config,
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END AS Missing_Pooling_Config,
    CASE WHEN c.ITEMNMBR NOT IN (
        SELECT Item_Number 
        FROM dbo.ETB2_Inventory_Unified 
        WHERE client = c.client AND contract = c.contract AND run = c.run
    ) THEN 1 ELSE 0 END AS Missing_Inventory_Data,
    CASE WHEN c.ITEMNMBR NOT IN (
        SELECT Item_Number 
        FROM dbo.ETB2_Demand_Cleaned_Base 
        WHERE client = c.client AND contract = c.contract AND run = c.run
    ) THEN 1 ELSE 0 END AS Missing_Demand_Data,
    CASE WHEN c.ITEMNMBR NOT IN (
        SELECT Item_Number 
        FROM dbo.ETB2_Campaign_Normalized_Demand 
        WHERE client = c.client AND contract = c.contract AND run = c.run
    ) THEN 1 ELSE 0 END AS Missing_Campaign_Data,
    CASE WHEN c.Lead_Time_Days = 30 AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.Pooling_Classification = 'Dedicated' AND c.Config_Status = 'Default' THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (
        SELECT Item_Number 
        FROM dbo.ETB2_Inventory_Unified 
        WHERE client = c.client AND contract = c.contract AND run = c.run
    ) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (
        SELECT Item_Number 
        FROM dbo.ETB2_Demand_Cleaned_Base 
        WHERE client = c.client AND contract = c.contract AND run = c.run
    ) THEN 1 ELSE 0 END +
    CASE WHEN c.ITEMNMBR NOT IN (
        SELECT Item_Number 
        FROM dbo.ETB2_Campaign_Normalized_Demand 
        WHERE client = c.client AND contract = c.contract AND run = c.run
    ) THEN 1 ELSE 0 END AS Total_Gap_Count,
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
        WHEN c.ITEMNMBR NOT IN (
            SELECT Item_Number 
            FROM dbo.ETB2_Inventory_Unified 
            WHERE client = c.client AND contract = c.contract AND run = c.run
        ) THEN ' No inventory data in work centers;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (
            SELECT Item_Number 
            FROM dbo.ETB2_Demand_Cleaned_Base 
            WHERE client = c.client AND contract = c.contract AND run = c.run
        ) THEN ' No demand history;'
        ELSE ''
    END +
    CASE 
        WHEN c.ITEMNMBR NOT IN (
            SELECT Item_Number 
            FROM dbo.ETB2_Campaign_Normalized_Demand 
            WHERE client = c.client AND contract = c.contract AND run = c.run
        ) THEN ' No campaign data.'
        ELSE ''
    END AS Gap_Description,
    CASE 
        WHEN c.ITEMNMBR NOT IN (
            SELECT Item_Number 
            FROM dbo.ETB2_Demand_Cleaned_Base 
            WHERE client = c.client AND contract = c.contract AND run = c.run
        ) THEN 1
        WHEN c.ITEMNMBR NOT IN (
            SELECT Item_Number 
            FROM dbo.ETB2_Inventory_Unified 
            WHERE client = c.client AND contract = c.contract AND run = c.run
        ) THEN 2
        ELSE 3
    END AS Remediation_Priority,
    
    -- FG SOURCE (PAB-style): Link to demand for FG info
    (SELECT TOP 1 d.FG_Item_Number 
     FROM dbo.ETB2_Demand_Cleaned_Base d 
     WHERE d.Item_Number = c.ITEMNMBR
       AND d.client = c.client AND d.contract = c.contract AND d.run = c.run) AS FG_Item_Number,
    (SELECT TOP 1 d.FG_Description 
     FROM dbo.ETB2_Demand_Cleaned_Base d 
     WHERE d.Item_Number = c.ITEMNMBR
       AND d.client = c.client AND d.contract = c.contract AND d.run = c.run) AS FG_Description,
    -- Construct SOURCE (PAB-style): Link to demand for Construct info
    (SELECT TOP 1 d.Construct 
     FROM dbo.ETB2_Demand_Cleaned_Base d 
     WHERE d.Item_Number = c.ITEMNMBR
       AND d.client = c.client AND d.contract = c.contract AND d.run = c.run) AS Construct,
    
    -- Suppression flag
    c.Is_Suppressed
    
FROM dbo.ETB2_Config_Active c WITH (NOLOCK)
WHERE c.ITEMNMBR NOT LIKE 'MO-%'
  AND c.Is_Suppressed = 0;

-- ============================================================================
-- END OF VIEW 16 (CONSOLIDATED FINAL)
-- ============================================================================
