-- ============================================================================
-- Table: dbo.ETB2_Config_Part_Pooling
-- Purpose: Configuration for part pooling classification
-- Grain: Item
-- Classifications:
--   - Pooled: Parts shared across multiple campaigns/products
--   - Semi-Pooled: Limited sharing, some exclusivity
--   - Dedicated: Campaign-specific, no sharing
-- Defaults: Dedicated (most conservative)
-- Assumptions:
--   - Classification owned by manufacturing engineering
--   - Review cadence: Quarterly or on new part introduction
--   - Default to Dedicated to avoid over-optimistic risk assessment
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE TABLE dbo.ETB2_Config_Part_Pooling (
    ITEMNMBR NVARCHAR(31) PRIMARY KEY,
    Pooling_Class NVARCHAR(20) NOT NULL CHECK (Pooling_Class IN ('Pooled', 'Semi-Pooled', 'Dedicated')),
    Last_Updated DATETIME2 DEFAULT GETUTCDATE(),
    Comments NVARCHAR(255) DEFAULT 'Default conservative classification'
);

-- Insert defaults for all existing items (Dedicated)
INSERT INTO dbo.ETB2_Config_Part_Pooling (ITEMNMBR, Pooling_Class, Comments)
SELECT DISTINCT
    ITEMNMBR,
    'Dedicated' AS Pooling_Class,
    'Default conservative classification - update based on manufacturing constraints'
FROM dbo.IV00101
WHERE ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Config_Part_Pooling);