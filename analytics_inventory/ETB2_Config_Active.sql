-- [T-001] Unified Active Configuration
-- Purpose: Returns one row per relevant Item/Client/Site combination with the effective configuration parameters
--          after applying the priority hierarchy: Item-specific > Client-specific > Global defaults.
--          Only includes currently active records (Effective_Date <= GETDATE() and Expiry_Date is null or > GETDATE()).
--          All columns are human-readable for planners. Sorted for easy Excel filtering.

WITH

-- 1. Global defaults (static VALUES from Rolyat_Config_Global)
GlobalConfig AS (
    SELECT
        'GLOBAL' AS Config_Source,
        3 AS Priority,  -- lowest priority
        Config_Key,
        Config_Value
    FROM (
        VALUES
            ('WFQ_Hold_Days', '14'),
            ('RMQTY_Hold_Days', '7'),
            ('WFQ_Expiry_Filter_Days', '90'),
            ('RMQTY_Expiry_Filter_Days', '90'),
            ('WC_Batch_Shelf_Life_Days', '180'),
            ('ActiveWindow_Past_Days', '21'),
            ('ActiveWindow_Future_Days', '21'),
            ('Safety_Stock_Days', '14'),
            ('Safety_Stock_Method', 'DAYS_OF_SUPPLY'),
            ('Degradation_Tier1_Days', '30'),
            ('Degradation_Tier1_Factor', '1.00'),
            ('Degradation_Tier2_Days', '60'),
            ('Degradation_Tier2_Factor', '0.75'),
            ('Degradation_Tier3_Days', '90'),
            ('Degradation_Tier3_Factor', '0.50'),
            ('Degradation_Tier4_Factor', '0.00')
    ) AS g(Config_Key, Config_Value)
),

-- 2. Client-specific overrides (from Rolyat_Config_Clients - currently placeholder/empty, but included for future)
ClientConfigRaw AS (
    SELECT
        Client_ID,
        Config_Key,
        Config_Value,
        Effective_Date,
        Expiry_Date
    FROM (VALUES
        -- Placeholder structure - real data would go here
        -- Example: ('CLI001', 'WFQ_Hold_Days', '10', '2025-01-01', NULL)
        (NULL, NULL, NULL, NULL, NULL)
    ) AS c(Client_ID, Config_Key, Config_Value, Effective_Date, Expiry_Date)
    WHERE Effective_Date <= GETDATE()
      AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())
      AND Client_ID IS NOT NULL
),

-- 3. Item-specific overrides (from Rolyat_Config_Items - currently placeholder/empty)
ItemConfigRaw AS (
    SELECT
        ITEMNMBR AS Item_Number,
        Config_Key,
        Config_Value,
        Effective_Date,
        Expiry_Date
    FROM (VALUES
        -- Placeholder structure - real data would go here
        -- Example: ('ITEM123', 'Safety_Stock_Days', '21', '2025-06-01', NULL)
        (NULL, NULL, NULL, NULL, NULL)
    ) AS i(ITEMNMBR, Config_Key, Config_Value, Effective_Date, Expiry_Date)
    WHERE Effective_Date <= GETDATE()
      AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())
      AND ITEMNMBR IS NOT NULL
),

-- 4. Site configuration (from Rolyat_Site_Config - hardcoded locations/types)
SiteConfig AS (
    SELECT
        LOCNCODE AS Location_Code,
        Site_Type,
        Active
    FROM (VALUES
        ('WC-CA01', 'WC', 1),
        ('WC-NY01', 'WC', 1),
        ('WFQ-CA01', 'WFQ', 1),
        ('RMQTY-CA01', 'RMQTY', 1)
        -- Add all actual site codes here when known
    ) AS s(LOCNCODE, Site_Type, Active)
    WHERE Active = 1
),

-- 5. Combine all sources and apply priority (highest = Item > Client > Global)
AllConfig AS (
    SELECT
        COALESCE(i.Item_Number, 'ALL_ITEMS') AS Item_Number,
        COALESCE(c.Client_ID, 'ALL_CLIENTS') AS Client_ID,
        s.Location_Code AS Site_ID,
        g.Config_Key,
        COALESCE(i.Config_Value, c.Config_Value, g.Config_Value) AS Effective_Value,
        ROW_NUMBER() OVER (
            PARTITION BY
                COALESCE(i.Item_Number, 'ALL_ITEMS'),
                COALESCE(c.Client_ID, 'ALL_CLIENTS'),
                s.Location_Code,
                g.Config_Key
            ORDER BY
                CASE
                    WHEN i.Config_Value IS NOT NULL THEN 1
                    WHEN c.Config_Value IS NOT NULL THEN 2
                    ELSE 3
                END
        ) AS rn
    FROM GlobalConfig g
    CROSS JOIN SiteConfig s
    LEFT JOIN ClientConfigRaw c
        ON 1=1  -- cross join unless Client_ID filtering logic is added
    LEFT JOIN ItemConfigRaw i
        ON 1=1  -- cross join unless Item-specific logic is added
)

-- Final pivoted output - one row per Item/Client/Site with all keys as columns
SELECT
    Item_Number,
    Client_ID,
    Site_ID,
    MAX(CASE WHEN Config_Key = 'WFQ_Hold_Days'              THEN Effective_Value END) AS WFQ_Hold_Days,
    MAX(CASE WHEN Config_Key = 'RMQTY_Hold_Days'            THEN Effective_Value END) AS RMQTY_Hold_Days,
    MAX(CASE WHEN Config_Key = 'WFQ_Expiry_Filter_Days'     THEN Effective_Value END) AS WFQ_Expiry_Filter_Days,
    MAX(CASE WHEN Config_Key = 'RMQTY_Expiry_Filter_Days'   THEN Effective_Value END) AS RMQTY_Expiry_Filter_Days,
    MAX(CASE WHEN Config_Key = 'WC_Batch_Shelf_Life_Days'   THEN Effective_Value END) AS WC_Shelf_Life_Days,
    MAX(CASE WHEN Config_Key = 'ActiveWindow_Past_Days'     THEN Effective_Value END) AS ActiveWindow_Past_Days,
    MAX(CASE WHEN Config_Key = 'ActiveWindow_Future_Days'   THEN Effective_Value END) AS ActiveWindow_Future_Days,
    MAX(CASE WHEN Config_Key = 'Safety_Stock_Days'          THEN Effective_Value END) AS Safety_Stock_Days,
    MAX(CASE WHEN Config_Key = 'Safety_Stock_Method'        THEN Effective_Value END) AS Safety_Stock_Method,
    MAX(CASE WHEN Config_Key = 'Degradation_Tier1_Days'     THEN Effective_Value END) AS Degradation_Tier1_Days,
    MAX(CASE WHEN Config_Key = 'Degradation_Tier1_Factor'   THEN Effective_Value END) AS Degradation_Tier1_Factor,
    MAX(CASE WHEN Config_Key = 'Degradation_Tier2_Days'     THEN Effective_Value END) AS Degradation_Tier2_Days,
    MAX(CASE WHEN Config_Key = 'Degradation_Tier2_Factor'   THEN Effective_Value END) AS Degradation_Tier2_Factor,
    MAX(CASE WHEN Config_Key = 'Degradation_Tier3_Days'     THEN Effective_Value END) AS Degradation_Tier3_Days,
    MAX(CASE WHEN Config_Key = 'Degradation_Tier3_Factor'   THEN Effective_Value END) AS Degradation_Tier3_Factor,
    MAX(CASE WHEN Config_Key = 'Degradation_Tier4_Factor'   THEN Effective_Value END) AS Degradation_Tier4_Factor
FROM AllConfig
WHERE rn = 1  -- only the highest-priority value per key
GROUP BY Item_Number, Client_ID, Site_ID
ORDER BY
    CASE WHEN Item_Number = 'ALL_ITEMS' THEN 1 ELSE 0 END,
    Item_Number,
    CASE WHEN Client_ID = 'ALL_CLIENTS' THEN 1 ELSE 0 END,
    Client_ID,
    Site_ID;
