/*
===============================================================================
View: dbo.Rolyat_Site_Config
Description: Site configuration defining WFQ and RMQTY locations
Version: 1.0.0
Last Modified: 2026-01-20
Dependencies:
   - None (static configuration)

Purpose:
   - Defines which locations are WFQ (quarantine) sites
   - Defines which locations are RMQTY (restricted material) sites
   - Provides active status for site configuration

Business Rules:
   - WF-Q location is designated for WFQ inventory
   - RMQTY location is designated for RMQTY inventory
   - All sites are active by default
===============================================================================
*/

SELECT
    'WF-Q' AS LOCNCODE,
    'WFQ' AS Site_Type,
    1 AS Active

UNION ALL

SELECT
    'RMQTY' AS LOCNCODE,
    'RMQTY' AS Site_Type,
    1 AS Active