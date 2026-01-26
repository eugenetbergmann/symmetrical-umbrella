-- ============================================================================
-- Table: dbo.ETB2_Config_Lead_Times
-- Purpose: Configuration for total effective lead times (supplier + QA + release)
-- Grain: Item
-- Assumptions:
--   - Default lead time: 30 days (conservative estimate for novel-modality CDMO)
--   - Lead time includes supplier delivery, QA testing, and release processes
--   - Update this table with actual lead times as data becomes available
--   - Items not in this table will use the default
-- Last Updated: 2026-01-26
-- ============================================================================

CREATE TABLE dbo.ETB2_Config_Lead_Times (
    ITEMNMBR NVARCHAR(31) PRIMARY KEY,
    Lead_Time_Days INT NOT NULL DEFAULT 30,
    Last_Updated DATETIME2 DEFAULT GETUTCDATE(),
    Comments NVARCHAR(255) DEFAULT 'Default conservative estimate'
);

-- Insert default for all existing items (if table is empty)
-- Note: This is a placeholder; actual lead times should be populated by supply chain team
INSERT INTO dbo.ETB2_Config_Lead_Times (ITEMNMBR, Lead_Time_Days, Comments)
SELECT DISTINCT
    ITEMNMBR,
    30 AS Lead_Time_Days,
    'Default conservative estimate - update with actual supplier lead times'
FROM dbo.IV00101
WHERE ITEMNMBR NOT IN (SELECT ITEMNMBR FROM dbo.ETB2_Config_Lead_Times);