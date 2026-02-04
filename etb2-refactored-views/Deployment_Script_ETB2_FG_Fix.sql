-- ============================================================================
-- ETB2 View Remediation: FG/Construct Fix - Deployment Script
-- ============================================================================
-- Purpose: Fix invalid column reference errors in ETB2 Views (04, 05, 06, 17)
-- Root Cause: ETB_PAB_MO table does not contain FG, FG Desc, or Customer columns
-- Solution: Swapped source table to ETB_ActiveDemand_Union_FG_MO which contains
--           FG_Item_Number, FG_Description, and Construct columns
-- Date: 2026-02-04
-- ============================================================================

USE [YourDatabaseName];
GO

PRINT '============================================================================';
PRINT 'ETB2 View Remediation: FG/Construct Fix';
PRINT '============================================================================';
PRINT 'Starting deployment at: ' + CONVERT(VARCHAR(19), GETDATE(), 120);
PRINT '';

-- ============================================================================
-- VIEW 04: dbo.ETB2_Demand_Cleaned_Base (FIXED)
-- ============================================================================
-- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
-- to resolve invalid column 'FG' errors.
-- ============================================================================

BEGIN TRY
    PRINT 'Creating/Altering View 04: dbo.ETB2_Demand_Cleaned_Base...';
    
    EXEC('
    CREATE OR ALTER VIEW [dbo].[ETB2_Demand_Cleaned_Base] AS
    WITH GlobalConfig AS (
        SELECT 90 AS Planning_Window_Days
    ),

    -- ============================================================================
    -- CleanOrder normalization logic (PAB-style)
    -- ============================================================================
    CleanOrderLogic AS (
        SELECT 
            ORDERNUMBER,
            -- CleanOrder: Strip MO, hyphens, spaces, punctuation, uppercase
            UPPER(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(ORDERNUMBER, ''MO'', ''''),
                                    ''-'', ''''
                                ),
                                '' '', ''''
                            ),
                            ''/'', ''''
                        ),
                        ''.'', ''''
                    ),
                    ''#'', ''''
                )
            ) AS CleanOrder
        FROM dbo.ETB_PAB_AUTO
        WHERE ITEMNMBR NOT LIKE ''60.%''
          AND ITEMNMBR NOT LIKE ''70.%''
          AND ITEMNMBR NOT LIKE ''MO-%''
          AND STSDESCR <> ''Partially Received''
    ),

    -- ============================================================================
    -- FG SOURCE (FIXED): Join to ETB_ActiveDemand_Union_FG_MO for FG + Construct derivation
    -- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
    -- to resolve invalid column ''FG'' errors.
    -- Uses ROW_NUMBER partitioning by CleanOrder + FG for deterministic selection
    -- ============================================================================
    FG_Source AS (
        SELECT
            col.ORDERNUMBER,
            col.CleanOrder,
            -- FG SOURCE (FIXED): Direct from ETB_ActiveDemand_Union_FG_MO table
            m.FG_Item_Number AS FG_Item_Number,
            -- FG Desc SOURCE (FIXED): Direct from ETB_ActiveDemand_Union_FG_MO table
            m.FG_Description AS FG_Description,
            -- Construct SOURCE (FIXED): Direct from ETB_ActiveDemand_Union_FG_MO table
            m.Construct AS Construct,
            -- Deduplication: Select deterministic FG row per CleanOrder
            ROW_NUMBER() OVER (
                PARTITION BY col.CleanOrder, m.FG_Item_Number
                ORDER BY m.Construct, m.FG_Description, col.ORDERNUMBER
            ) AS FG_RowNum
        FROM CleanOrderLogic col
        INNER JOIN dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
            ON col.CleanOrder = UPPER(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(m.ORDERNUMBER, ''MO'', ''''),
                                    ''-'', ''''
                                ),
                                '' '', ''''
                            ),
                            ''/'', ''''
                        ),
                            ''.'', ''''
                        ),
                        ''#'', ''''
                    )
                )
            )
    ),

    -- ============================================================================
    -- Deduplicated FG rows (rn = 1 per CleanOrder + FG)
    -- ============================================================================
    FG_Deduped AS (
        SELECT
            ORDERNUMBER,
            CleanOrder,
            FG_Item_Number,
            FG_Description,
            Construct
        FROM FG_Source
        WHERE FG_RowNum = 1
    ),

    RawDemand AS (
        SELECT
            -- Context columns
            ''DEFAULT_CLIENT'' AS client,
            ''DEFAULT_CONTRACT'' AS contract,
            ''CURRENT_RUN'' AS run,
            
            pa.ORDERNUMBER,
            pa.ITEMNMBR,
            pa.DUEDATE,
            pa.REMAINING,
            pa.DEDUCTIONS,
            pa.EXPIRY,
            pa.STSDESCR,
            pa.[Date + Expiry] AS Date_Expiry_String,
            pa.MRP_IssueDate,
            TRY_CONVERT(DATE, pa.DUEDATE) AS Due_Date_Clean,
            TRY_CONVERT(DATE, pa.[Date + Expiry]) AS Expiry_Date_Clean,
            pvi.ITEMDESC AS Item_Description,
            pvi.UOMSCHDL,
            ''MAIN'' AS Site,
            
            -- FG SOURCE (PAB-style): Carried through from deduped FG join
            fd.FG_Item_Number,
            fd.FG_Description,
            -- Construct SOURCE (PAB-style): Carried through from deduped FG join
            fd.Construct
            
        FROM dbo.ETB_PAB_AUTO pa WITH (NOLOCK)
        INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
          ON LTRIM(RTRIM(pa.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
        -- FG SOURCE (PAB-style): Left join to carry FG/Construct forward
        LEFT JOIN FG_Deduped fd
            ON pa.ORDERNUMBER = fd.ORDERNUMBER
        WHERE pa.ITEMNMBR NOT LIKE ''60.%''
          AND pa.ITEMNMBR NOT LIKE ''70.%''
          AND pa.ITEMNMBR NOT LIKE ''MO-%''
          AND pa.STSDESCR <> ''Partially Received''
          AND pvi.Active = ''Yes''
          AND TRY_CONVERT(DATE, pa.DUEDATE) BETWEEN
              DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
              AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    ),

    CleanedDemand AS (
        SELECT
            -- Context columns preserved
            client,
            contract,
            run,
            
            ORDERNUMBER,
            ITEMNMBR,
            STSDESCR,
            Site,
            Item_Description,
            UOMSCHDL,
            Due_Date_Clean AS Due_Date,
            COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0) AS Remaining_Qty,
            COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0) AS Deductions_Qty,
            COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0) AS Expiry_Qty,
            Expiry_Date_Clean AS Expiry_Date,
            MRP_IssueDate,
            CASE
                WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0)
                WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0)
                WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0)
                ELSE 0.0
            END AS Base_Demand_Qty,
            CASE
                WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN ''Remaining''
                WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN ''Deductions''
                WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN ''Expiry''
                ELSE ''Zero''
            END AS Demand_Priority_Type,
            CASE
                WHEN Due_Date_Clean BETWEEN
                    DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
                    AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
                THEN 1 ELSE 0
            END AS Is_Within_Active_Planning_Window,
            CASE
                WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN 3
                WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN 3
                WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN 4
                ELSE 5
            END AS Event_Sort_Priority,
            -- CleanOrder: Strip MO, hyphens, spaces, punctuation, uppercase
            UPPER(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(ORDERNUMBER, ''MO'', ''''),
                                    ''-'', ''''
                                ),
                                '' '', ''''
                            ),
                            ''/'', ''''
                        ),
                        ''.'', ''''
                    ),
                    ''#'', ''''
                )
            ) AS Clean_Order_Number,
            
            -- Suppression flag
            CAST(0 AS BIT) AS Is_Suppressed,
            
            -- FG SOURCE (PAB-style): Carried through from base
            FG_Item_Number,
            FG_Description,
            -- Construct SOURCE (PAB-style): Carried through from base
            Construct
            
        FROM RawDemand
        WHERE Due_Date_Clean IS NOT NULL
          AND (COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0)) > 0
    )

    -- ============================================================
    -- FINAL OUTPUT: Demand with FG + Construct carried through
    -- ============================================================
    SELECT
        -- Context columns preserved
        cd.client,
        cd.contract,
        cd.run,
        
        Clean_Order_Number AS Order_Number,
        ITEMNMBR AS Item_Number,
        COALESCE(ci.Item_Description, cd.Item_Description) AS Item_Description,
        ci.UOM_Schedule,
        Site,
        Due_Date,
        STSDESCR AS Status_Description,
        Base_Demand_Qty,
        Expiry_Qty,
        Expiry_Date,
        UOMSCHDL AS Unit_Of_Measure,
        Remaining_Qty,
        Deductions_Qty,
        Demand_Priority_Type,
        Is_Within_Active_Planning_Window,
        Event_Sort_Priority,
        MRP_IssueDate,
        
        -- Suppression flag
        CAST(cd.Is_Suppressed | COALESCE(ci.Is_Suppressed, 0) AS BIT) AS Is_Suppressed,
        
        -- ROW_NUMBER with context in PARTITION BY
        ROW_NUMBER() OVER (
            PARTITION BY client, contract, run, ITEMNMBR
            ORDER BY Due_Date ASC, Base_Demand_Qty DESC
        ) AS Demand_Sequence,
        
        -- FG SOURCE (PAB-style): Exposed in final output
        FG_Item_Number,
        FG_Description,
        -- Construct SOURCE (PAB-style): Exposed in final output
        Construct
        
    FROM CleanedDemand cd
    LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
        ON cd.ITEMNMBR = ci.Item_Number;
    ');
    
    PRINT 'SUCCESS: View 04 created/altered successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to create/alter View 04.';
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
END CATCH
GO

PRINT '';

-- ============================================================================
-- VIEW 05: dbo.ETB2_Inventory_WC_Batches (FIXED)
-- ============================================================================
-- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
-- to resolve invalid column 'FG' errors.
-- ============================================================================

BEGIN TRY
    PRINT 'Creating/Altering View 05: dbo.ETB2_Inventory_WC_Batches...';
    
    EXEC('
    CREATE OR ALTER VIEW [dbo].[ETB2_Inventory_WC_Batches] AS
    WITH GlobalShelfLife AS (
        SELECT 180 AS Default_WC_Shelf_Life_Days
    ),

    -- ============================================================================
    -- FG SOURCE (FIXED): Derive FG from ETB_ActiveDemand_Union_FG_MO
    -- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
    -- to resolve invalid column ''FG'' errors.
    -- ============================================================================
    FG_From_MO AS (
        SELECT
            m.ORDERNUMBER,
            m.FG_Item_Number AS FG_Item_Number,
            m.FG_Description AS FG_Description,
            m.Construct AS Construct,
            UPPER(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(m.ORDERNUMBER, ''MO'', ''''),
                                    ''-'', ''''
                                ),
                                '' '', ''''
                            ),
                            ''/'', ''''
                        ),
                        ''.'', ''''
                    ),
                    ''#'', ''''
                )
            ) AS CleanOrder
        FROM dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
        WHERE m.FG_Item_Number IS NOT NULL
          AND m.FG_Item_Number <> ''''
    ),

    RawWCInventory AS (
        SELECT
            -- Context columns
            ''DEFAULT_CLIENT'' AS client,
            ''DEFAULT_CONTRACT'' AS contract,
            ''CURRENT_RUN'' AS run,
            
            pib.Item_Number AS ITEMNMBR,
            pib.LOT_NUMBER,
            pib.Bin AS BIN,
            pib.SITE AS LOCNCODE,
            pib.QTY_Available,
            pib.DATERECD,
            pib.EXPNDATE
        FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
        WHERE pib.SITE LIKE ''WC[_-]%''
          AND pib.QTY_Available > 0
          AND pib.LOT_NUMBER IS NOT NULL
          AND pib.LOT_NUMBER <> ''''
          AND pib.Item_Number NOT LIKE ''MO-%''
          AND CAST(GETDATE() AS DATE) BETWEEN 
              DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
              AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    ),

    -- ============================================================================
    -- Link inventory to FG via Lot Number pattern matching
    -- ============================================================================
    InventoryWithFG AS (
        SELECT
            ri.client,
            ri.contract,
            ri.run,
            ri.ITEMNMBR,
            ri.LOT_NUMBER,
            ri.BIN,
            ri.LOCNCODE,
            ri.QTY_Available,
            ri.DATERECD,
            ri.EXPNDATE,
            -- FG SOURCE (PAB-style): Link via lot/order patterns
            fg.FG_Item_Number,
            fg.FG_Description,
            fg.Construct,
            ROW_NUMBER() OVER (
                PARTITION BY ri.ITEMNMBR, ri.LOT_NUMBER
                ORDER BY 
                    CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END,
                    fg.FG_Item_Number
            ) AS FG_Priority
        FROM RawWCInventory ri
        LEFT JOIN FG_From_MO fg
            ON ri.LOT_NUMBER LIKE ''%'' + fg.CleanOrder + ''%''
            OR fg.CleanOrder LIKE ''%'' + REPLACE(ri.LOT_NUMBER, ''-'', '''') + ''%''
    ),

    ParsedInventory AS (
        SELECT
            -- Context columns preserved
            ii.client,
            ii.contract,
            ii.run,
            
            ii.ITEMNMBR,
            ii.LOT_NUMBER,
            ii.BIN,
            ii.LOCNCODE,
            ii.QTY_Available,
            CAST(ii.DATERECD AS DATE) AS Receipt_Date,
            COALESCE(
                TRY_CONVERT(DATE, ii.EXPNDATE),
                DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ii.DATERECD AS DATE))
            ) AS Expiry_Date,
            DATEDIFF(DAY, CAST(ii.DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
            LEFT(ii.LOCNCODE, PATINDEX(''%[-_]%'', ii.LOCNCODE + ''-'') - 1) AS Client_ID,
            itm.ITEMDESC AS Item_Description,
            itm.UOMSCHDL AS Unit_Of_Measure,
            
            -- Suppression flag
            CAST(0 AS BIT) AS Is_Suppressed,
            
            -- FG SOURCE (PAB-style): Carried through from MO linkage
            ii.FG_Item_Number,
            ii.FG_Description,
            -- Construct SOURCE (PAB-style): Carried through from MO linkage
            ii.Construct
            
        FROM InventoryWithFG ii
        CROSS JOIN GlobalShelfLife gsl
        LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
            ON LTRIM(RTRIM(ii.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
        WHERE ii.FG_Priority = 1  -- Select best FG match per lot
          AND COALESCE(
                TRY_CONVERT(DATE, ii.EXPNDATE),
                DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ii.DATERECD AS DATE))
              ) >= CAST(GETDATE() AS DATE)  -- Exclude expired
    )

    -- ============================================================
    -- FINAL OUTPUT: 20 columns, planner-optimized order
    -- LEFT → RIGHT = IDENTIFY → LOCATE → QUANTIFY → TIME → DECIDE → FG/CONSTRUCT
    -- ============================================================
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        -- IDENTIFY (what item?) - 3 columns
        ITEMNMBR                AS Item_Number,
        Item_Description,
        Unit_Of_Measure,

        -- LOCATE (where is it?) - 4 columns
        Client_ID,
        LOCNCODE                AS Site,
        BIN                     AS Bin,
        LOT_NUMBER              AS Lot,

        -- QUANTIFY (how much?) - 2 columns
        QTY_Available           AS Quantity,
        QTY_Available           AS Usable_Qty,

        -- TIME (when relevant?) - 3 columns
        Receipt_Date,
        Expiry_Date,
        DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,

        -- DECIDE (what action?) - 3 columns
        ROW_NUMBER() OVER (
            PARTITION BY client, contract, run, ITEMNMBR
            ORDER BY Expiry_Date ASC, Receipt_Date ASC
        ) AS Use_Sequence,
        ''WC_BATCH''              AS Batch_Type,
        
        -- Suppression flag
        Is_Suppressed,

        -- FG SOURCE (PAB-style): Exposed in final output
        FG_Item_Number,
        FG_Description,
        -- Construct SOURCE (PAB-style): Exposed in final output
        Construct

    FROM ParsedInventory
    WHERE Is_Suppressed = 0;
    ');
    
    PRINT 'SUCCESS: View 05 created/altered successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to create/alter View 05.';
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
END CATCH
GO

PRINT '';

-- ============================================================================
-- VIEW 06: dbo.ETB2_Inventory_Quarantine_Restricted (FIXED)
-- ============================================================================
-- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
-- to resolve invalid column 'FG' errors.
-- ============================================================================

BEGIN TRY
    PRINT 'Creating/Altering View 06: dbo.ETB2_Inventory_Quarantine_Restricted...';
    
    EXEC('
    CREATE OR ALTER VIEW [dbo].[ETB2_Inventory_Quarantine_Restricted] AS
    WITH GlobalConfig AS (
        SELECT
            14 AS WFQ_Hold_Days,
            7 AS RMQTY_Hold_Days,
            90 AS Expiry_Filter_Days
    ),

    -- ============================================================================
    -- FG SOURCE (FIXED): Derive FG from ETB_ActiveDemand_Union_FG_MO
    -- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
    -- to resolve invalid column ''FG'' errors.
    -- ============================================================================
    FG_From_MO AS (
        SELECT
            m.ORDERNUMBER,
            m.FG_Item_Number AS FG_Item_Number,
            m.FG_Description AS FG_Description,
            m.Construct AS Construct,
            UPPER(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(m.ORDERNUMBER, ''MO'', ''''),
                                    ''-'', ''''
                                ),
                                '' '', ''''
                            ),
                            ''/'', ''''
                        ),
                        ''.'', ''''
                    ),
                    ''#'', ''''
                )
            ) AS CleanOrder
        FROM dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
        WHERE m.FG_Item_Number IS NOT NULL
          AND m.FG_Item_Number <> ''''
    ),

    RawWFQInventory AS (
        SELECT
            -- Context columns
            ''DEFAULT_CLIENT'' AS client,
            ''DEFAULT_CONTRACT'' AS contract,
            ''CURRENT_RUN'' AS run,
            
            inv.ITEMNMBR,
            inv.LOCNCODE,
            inv.RCTSEQNM,
            inv.LOTNUMBR,
            COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
            inv.DATERECD,
            inv.EXPNDATE,
            itm.UOMSCHDL,
            itm.ITEMDESC
        FROM dbo.IV00300 inv WITH (NOLOCK)
        LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
        WHERE TRIM(inv.LOCNCODE) = ''WF-Q''
          AND inv.ITEMNMBR NOT LIKE ''MO-%''
          AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
          AND (inv.EXPNDATE IS NULL
               OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
          AND CAST(GETDATE() AS DATE) BETWEEN 
              DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
              AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    ),

    RawRMQTYInventory AS (
        SELECT
            -- Context columns
            ''DEFAULT_CLIENT'' AS client,
            ''DEFAULT_CONTRACT'' AS contract,
            ''CURRENT_RUN'' AS run,
            
            inv.ITEMNMBR,
            inv.LOCNCODE,
            inv.RCTSEQNM,
            inv.LOTNUMBR,
            COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
            inv.DATERECD,
            inv.EXPNDATE,
            itm.UOMSCHDL,
            itm.ITEMDESC
        FROM dbo.IV00300 inv WITH (NOLOCK)
        LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
        WHERE TRIM(inv.LOCNCODE) = ''RMQTY''
          AND inv.ITEMNMBR NOT LIKE ''MO-%''
          AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
          AND (inv.EXPNDATE IS NULL
               OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
          AND CAST(GETDATE() AS DATE) BETWEEN 
              DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
              AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
    ),

    -- ============================================================================
    -- Link WFQ inventory to FG via Lot Number
    -- ============================================================================
    WFQWithFG AS (
        SELECT
            ri.client, ri.contract, ri.run,
            ri.ITEMNMBR, ri.LOCNCODE, ri.RCTSEQNM, ri.QTY_ON_HAND,
            ri.DATERECD, ri.EXPNDATE, ri.UOMSCHDL, ri.ITEMDESC,
            fg.FG_Item_Number, fg.FG_Description, fg.Construct,
            ROW_NUMBER() OVER (
                PARTITION BY ri.ITEMNMBR, ri.RCTSEQNM
                ORDER BY CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END, fg.FG_Item_Number
            ) AS FG_Priority
        FROM RawWFQInventory ri
        LEFT JOIN FG_From_MO fg
            ON ri.LOTNUMBR LIKE ''%'' + fg.CleanOrder + ''%''
            OR fg.CleanOrder LIKE ''%'' + REPLACE(ri.LOTNUMBR, ''-'', '''') + ''%''
    ),

    -- ============================================================================
    -- Link RMQTY inventory to FG via Lot Number
    -- ============================================================================
    RMQTYWithFG AS (
        SELECT
            ri.client, ri.contract, ri.run,
            ri.ITEMNMBR, ri.LOCNCODE, ri.RCTSEQNM, ri.QTY_ON_HAND,
            ri.DATERECD, ri.EXPNDATE, ri.UOMSCHDL, ri.ITEMDESC,
            fg.FG_Item_Number, fg.FG_Description, fg.Construct,
            ROW_NUMBER() OVER (
                PARTITION BY ri.ITEMNMBR, ri.RCTSEQNM
                ORDER BY CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END, fg.FG_Item_Number
            ) AS FG_Priority
        FROM RawRMQTYInventory ri
        LEFT JOIN FG_From_MO fg
            ON ri.LOTNUMBR LIKE ''%'' + fg.CleanOrder + ''%''
            OR fg.CleanOrder LIKE ''%'' + REPLACE(ri.LOTNUMBR, ''-'', '''') + ''%''
    ),

    ParsedWFQInventory AS (
        SELECT
            client, contract, run,
            ITEMNMBR,
            MAX(ITEMDESC) AS Item_Description,
            MAX(UOMSCHDL) AS Unit_Of_Measure,
            LOCNCODE,
            SUM(QTY_ON_HAND) AS Available_Quantity,
            MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
            MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
            DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Release_Date,
            DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
            CASE
                WHEN DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
                THEN 1 ELSE 0
            END AS Is_Released,
            ''WFQ'' AS Hold_Type,
            CAST(0 AS BIT) AS Is_Suppressed,
            -- FG SOURCE (PAB-style)
            MAX(FG_Item_Number) AS FG_Item_Number,
            MAX(FG_Description) AS FG_Description,
            MAX(Construct) AS Construct
        FROM WFQWithFG
        WHERE FG_Priority = 1
        GROUP BY client, contract, run, ITEMNMBR, LOCNCODE
        HAVING SUM(QTY_ON_HAND) <> 0
    ),

    ParsedRMQTYInventory AS (
        SELECT
            client, contract, run,
            ITEMNMBR,
            MAX(ITEMDESC) AS Item_Description,
            MAX(UOMSCHDL) AS Unit_Of_Measure,
            LOCNCODE,
            SUM(QTY_ON_HAND) AS Available_Quantity,
            MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
            MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
            DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Release_Date,
            DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
            CASE
                WHEN DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
                THEN 1 ELSE 0
            END AS Is_Released,
            ''RMQTY'' AS Hold_Type,
            CAST(0 AS BIT) AS Is_Suppressed,
            -- FG SOURCE (PAB-style)
            MAX(FG_Item_Number) AS FG_Item_Number,
            MAX(FG_Description) AS FG_Description,
            MAX(Construct) AS Construct
        FROM RMQTYWithFG
        WHERE FG_Priority = 1
        GROUP BY client, contract, run, ITEMNMBR, LOCNCODE
        HAVING SUM(QTY_ON_HAND) <> 0
    )

    -- ============================================================
    -- FINAL OUTPUT: 19 columns with FG/Construct
    -- ============================================================
    SELECT
        client, contract, run,
        ITEMNMBR AS Item_Number,
        Item_Description,
        Unit_Of_Measure,
        LOCNCODE AS Site,
        Hold_Type,
        Available_Quantity AS Quantity,
        Available_Quantity AS Usable_Qty,
        Receipt_Date,
        Expiry_Date,
        Age_Days,
        Release_Date,
        DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,
        Is_Released AS Can_Allocate,
        ROW_NUMBER() OVER (
            PARTITION BY client, contract, run, ITEMNMBR
            ORDER BY Release_Date ASC, Receipt_Date ASC
        ) AS Use_Sequence,
        Is_Suppressed,
        -- FG SOURCE (PAB-style)
        FG_Item_Number,
        FG_Description,
        Construct
    FROM ParsedWFQInventory
    WHERE Is_Suppressed = 0

    UNION ALL

    SELECT
        client, contract, run,
        ITEMNMBR AS Item_Number,
        Item_Description,
        Unit_Of_Measure,
        LOCNCODE AS Site,
        Hold_Type,
        Available_Quantity AS Quantity,
        Available_Quantity AS Usable_Qty,
        Receipt_Date,
        Expiry_Date,
        Age_Days,
        Release_Date,
        DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,
        Is_Released AS Can_Allocate,
        ROW_NUMBER() OVER (
            PARTITION BY client, contract, run, ITEMNMBR
            ORDER BY Release_Date ASC, Receipt_Date ASC
        ) AS Use_Sequence,
        Is_Suppressed,
        -- FG SOURCE (PAB-style)
        FG_Item_Number,
        FG_Description,
        Construct
    FROM ParsedRMQTYInventory
    WHERE Is_Suppressed = 0;
    ');
    
    PRINT 'SUCCESS: View 06 created/altered successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to create/alter View 06.';
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
END CATCH
GO

PRINT '';

-- ============================================================================
-- VIEW 17: dbo.ETB2_PAB_EventLedger_v1 (FIXED)
-- ============================================================================
-- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
-- to resolve invalid column 'FG' errors.
-- ============================================================================

BEGIN TRY
    PRINT 'Creating/Altering View 17: dbo.ETB2_PAB_EventLedger_v1...';
    
    EXEC('
    CREATE OR ALTER VIEW [dbo].[ETB2_PAB_EventLedger_v1] AS
    -- ============================================================================
    -- FG SOURCE (FIXED): Pre-calculate FG/Construct from ETB_ActiveDemand_Union_FG_MO
    -- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
    -- to resolve invalid column ''FG'' errors.
    -- ============================================================================
    WITH FG_From_MO AS (
        SELECT
            m.ORDERNUMBER,
            m.FG_Item_Number AS FG_Item_Number,
            m.FG_Description AS FG_Description,
            m.Construct AS Construct,
            UPPER(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(m.ORDERNUMBER, ''MO'', ''''),
                                    ''-'', ''''
                                ),
                                '' '', ''''
                            ),
                            ''/'', ''''
                        ),
                        ''.'', ''''
                    ),
                    ''#'', ''''
                )
            ) AS CleanOrder
        FROM dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
        WHERE m.FG_Item_Number IS NOT NULL
          AND m.FG_Item_Number <> ''''
    ),

    -- ============================================================================
    -- CleanOrder mapping for PAB_AUTO
    -- ============================================================================
    PABWithCleanOrder AS (
        SELECT
            pab.ORDERNUMBER,
            pab.ITEMNMBR,
            pab.DUEDATE,
            pab.Running_Balance,
            pab.STSDESCR,
            UPPER(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(pab.ORDERNUMBER, ''MO'', ''''),
                                    ''-'', ''''
                                ),
                                '' '', ''''
                            ),
                            ''/'', ''''
                        ),
                        ''.'', ''''
                    ),
                    ''#'', ''''
                )
            ) AS CleanOrder
        FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
        WHERE pab.STSDESCR <> ''Partially Received''
          AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE ''60.%''
          AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE ''70.%''
          AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE ''MO-%''
    )

    -- Part 1: Purchase Orders
    SELECT 
        -- Context columns
        ''DEFAULT_CLIENT'' AS client,
        ''DEFAULT_CONTRACT'' AS contract,
        ''CURRENT_RUN'' AS run,
        
        LTRIM(RTRIM(p.PONUMBER)) AS Order_Number,
        LTRIM(RTRIM(p.VENDORID)) AS Vendor_ID,
        pd.ITEMNMBR AS Item_Number,
        pd.UOFM AS Unit_Of_Measure,
        COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) AS Ordered_Qty,
        COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) AS Received_Qty,
        COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) AS Remaining_Qty,
        CASE 
            WHEN COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) > 0 THEN ''RECEIVED''
            WHEN COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) = COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) THEN ''OPEN''
            WHEN COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) < COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) AND COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) > 0 THEN ''PARTIAL''
            ELSE ''PENDING''
        END AS Event_Type,
        TRY_CONVERT(DATE, p.DOCDATE) AS Order_Date,
        TRY_CONVERT(DATE, p.REQDATE) AS Required_Date,
        GETDATE() AS ETB2_Load_Date,
        ISNULL(i.ITEMDESC, '''') AS Item_Description,
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed,
        
        -- FG SOURCE (PAB-style): NULL for PO events (no MO linkage)
        NULL AS FG_Item_Number,
        NULL AS FG_Description,
        -- Construct SOURCE (PAB-style): NULL for PO events (no MO linkage)
        NULL AS Construct
        
    FROM dbo.POP10100 p WITH (NOLOCK)
    INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
    LEFT JOIN dbo.IV00102 i WITH (NOLOCK) ON pd.ITEMNMBR = i.ITEMNMBR
    WHERE pd.ITEMNMBR IN (
        SELECT Item_Number 
        FROM dbo.ETB2_Demand_Cleaned_Base 
        WHERE client = ''DEFAULT_CLIENT'' AND contract = ''DEFAULT_CONTRACT'' AND run = ''CURRENT_RUN''
    )
      AND pd.ITEMNMBR NOT LIKE ''MO-%''
      AND TRY_CONVERT(DATE, p.DOCDATE) BETWEEN
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))

    UNION ALL

    -- Part 2: PAB Auto Demand
    SELECT 
        -- Context columns
        ''DEFAULT_CLIENT'' AS client,
        ''DEFAULT_CONTRACT'' AS contract,
        ''CURRENT_RUN'' AS run,
        
        LTRIM(RTRIM(pco.ORDERNUMBER)) AS Order_Number,
        '''' AS Vendor_ID,
        LTRIM(RTRIM(pco.ITEMNMBR)) AS Item_Number,
        '''' AS Unit_Of_Measure,
        CASE 
            WHEN ISNUMERIC(LTRIM(RTRIM(pco.Running_Balance))) = 1 
            THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pco.Running_Balance)) AS DECIMAL(18,5)), 0)
            ELSE 0 
        END AS Ordered_Qty,
        0 AS Received_Qty,
        CASE 
            WHEN ISNUMERIC(LTRIM(RTRIM(pco.Running_Balance))) = 1 
            THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pco.Running_Balance)) AS DECIMAL(18,5)), 0)
            ELSE 0 
        END AS Remaining_Qty,
        ''DEMAND'' AS Event_Type,
        TRY_CONVERT(DATE, pco.DUEDATE) AS Order_Date,
        TRY_CONVERT(DATE, pco.DUEDATE) AS Required_Date,
        GETDATE() AS ETB2_Load_Date,
        ISNULL(vi.ITEMDESC, '''') AS Item_Description,
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed,
        
        -- FG SOURCE (PAB-style): From ETB_ActiveDemand_Union_FG_MO linkage
        fg.FG_Item_Number,
        fg.FG_Description,
        -- Construct SOURCE (PAB-style): From ETB_ActiveDemand_Union_FG_MO linkage
        fg.Construct
        
    FROM PABWithCleanOrder pco
    LEFT JOIN dbo.Prosenthal_Vendor_Items vi WITH (NOLOCK) 
        ON LTRIM(RTRIM(pco.ITEMNMBR)) = LTRIM(RTRIM(vi.[Item Number]))
    LEFT JOIN FG_From_MO fg
        ON pco.CleanOrder = fg.CleanOrder;
    ');
    
    PRINT 'SUCCESS: View 17 created/altered successfully.';
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to create/alter View 17.';
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
END CATCH
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Deployment completed at: ' + CONVERT(VARCHAR(19), GETDATE(), 120);
PRINT '============================================================================';
PRINT '';
PRINT 'Summary of changes:';
PRINT '  - View 04: ETB2_Demand_Cleaned_Base - FIXED';
PRINT '  - View 05: ETB2_Inventory_WC_Batches - FIXED';
PRINT '  - View 06: ETB2_Inventory_Quarantine_Restricted - FIXED';
PRINT '  - View 17: ETB2_PAB_EventLedger_v1 - FIXED';
PRINT '';
PRINT 'All views now use ETB_ActiveDemand_Union_FG_MO as the source for FG data.';
PRINT 'Views 07-16 inherit FG/Construct data from the fixed views above.';
PRINT '============================================================================';
GO
