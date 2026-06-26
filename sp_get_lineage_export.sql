-- ============================================
-- Procédure stockée: sp_get_lineage_export
-- Description: Récupère le lignage complet avec export Excel
-- Améliorations:
--   - Limite de récursion (évite boucles infinies)
--   - Chemin complet de navigation
--   - Compatible export Excel via BCP/SQLCMD
-- ============================================
CREATE OR ALTER PROCEDURE sp_get_lineage_export
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1),
    @p_sc       CHAR(1),            -- 'S' = Successeur, 'P' = Prédécesseur
    @p_max_level INT = 100          -- Limite de niveaux (défaut 100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_filter_edgdir CHAR(1);

    -- Déterminer la direction de filtre
    SET @v_filter_edgdir = CASE
        WHEN @p_sc = 'S' THEN 'O'
        WHEN @p_sc = 'P' THEN 'I'
        ELSE NULL
    END;

    IF @v_filter_edgdir IS NULL
    BEGIN
        RAISERROR('Paramètre SC invalide. Utilisez ''S'' ou ''P''.', 16, 1);
        RETURN;
    END

    -- CTE récursive avec chemin et limite
    ;WITH LineageRecursive AS (
        -- Niveau 0 (point de départ)
        SELECT
            0 AS niveau,
            CAST(@p_uid AS NVARCHAR(MAX)) AS chemin_uid,
            CAST(@p_uid AS NVARCHAR(255)) AS src_uid,
            CAST(@p_lnuid AS NVARCHAR(255)) AS src_lnuid,
            CAST(@p_edgdir AS NVARCHAR(255)) AS src_edgdir,
            CAST(NULL AS NVARCHAR(255)) AS dta1,
            CAST(NULL AS NVARCHAR(255)) AS dta2,
            CAST(NULL AS NVARCHAR(255)) AS dta3,
            CAST(NULL AS NVARCHAR(255)) AS dta4

        UNION ALL

        -- Niveaux suivants
        SELECT
            lr.niveau + 1,
            lr.chemin_uid + ' -> ' + lve.dta1,
            CAST(lve.dta1 AS NVARCHAR(255)),
            CAST(lve.dta2 AS NVARCHAR(255)),
            CAST(lve.dta3 AS NVARCHAR(255)),
            lve.dta1,
            lve.dta2,
            lve.dta3,
            lve.dta4
        FROM lin_vis_edg lve
        INNER JOIN LineageRecursive lr
            ON lve.edg1 = lr.src_uid
            AND lve.edg2 = lr.src_lnuid
            AND lve.edg3 = lr.src_edgdir
        WHERE lve.edgdir = @v_filter_edgdir
          AND lr.niveau < @p_max_level
          -- Éviter les cycles
          AND CHARINDEX(lve.dta1, lr.chemin_uid) = 0
    )
    SELECT
        niveau,
        CASE WHEN @p_sc = 'S' THEN 'Successeur' ELSE 'Predecesseur' END AS direction,
        chemin_uid AS chemin,
        dta1,
        dta2,
        dta3,
        dta4
    FROM LineageRecursive
    WHERE niveau > 0
    ORDER BY niveau;

END;
GO

-- ============================================
-- Procédure pour export CSV (compatible Excel)
-- ============================================
CREATE OR ALTER PROCEDURE sp_export_lineage_csv
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1),
    @p_sc       CHAR(1),
    @p_filepath NVARCHAR(500) = NULL  -- Chemin fichier (optionnel)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_filter_edgdir CHAR(1);

    SET @v_filter_edgdir = CASE
        WHEN @p_sc = 'S' THEN 'O'
        WHEN @p_sc = 'P' THEN 'I'
        ELSE NULL
    END;

    IF @v_filter_edgdir IS NULL
    BEGIN
        RAISERROR('Paramètre SC invalide.', 16, 1);
        RETURN;
    END

    -- Résultat formaté CSV avec en-têtes
    ;WITH LineageRecursive AS (
        SELECT
            0 AS niveau,
            CAST(@p_uid AS NVARCHAR(MAX)) AS chemin_uid,
            CAST(@p_uid AS NVARCHAR(255)) AS src_uid,
            CAST(@p_lnuid AS NVARCHAR(255)) AS src_lnuid,
            CAST(@p_edgdir AS NVARCHAR(255)) AS src_edgdir,
            CAST(NULL AS NVARCHAR(255)) AS dta1,
            CAST(NULL AS NVARCHAR(255)) AS dta2,
            CAST(NULL AS NVARCHAR(255)) AS dta3,
            CAST(NULL AS NVARCHAR(255)) AS dta4

        UNION ALL

        SELECT
            lr.niveau + 1,
            lr.chemin_uid + ' -> ' + lve.dta1,
            CAST(lve.dta1 AS NVARCHAR(255)),
            CAST(lve.dta2 AS NVARCHAR(255)),
            CAST(lve.dta3 AS NVARCHAR(255)),
            lve.dta1,
            lve.dta2,
            lve.dta3,
            lve.dta4
        FROM lin_vis_edg lve
        INNER JOIN LineageRecursive lr
            ON lve.edg1 = lr.src_uid
            AND lve.edg2 = lr.src_lnuid
            AND lve.edg3 = lr.src_edgdir
        WHERE lve.edgdir = @v_filter_edgdir
          AND lr.niveau < 100
          AND CHARINDEX(lve.dta1, lr.chemin_uid) = 0
    )
    SELECT
        CAST(niveau AS NVARCHAR(10)) AS Niveau,
        CASE WHEN @p_sc = 'S' THEN 'Successeur' ELSE 'Predecesseur' END AS Direction,
        chemin_uid AS Chemin,
        ISNULL(dta1, '') AS DTA1,
        ISNULL(dta2, '') AS DTA2,
        ISNULL(dta3, '') AS DTA3,
        ISNULL(dta4, '') AS DTA4
    FROM LineageRecursive
    WHERE niveau > 0
    ORDER BY niveau;

END;
GO

-- ============================================
-- Exemples d'utilisation:
-- ============================================

-- 1. Afficher le lignage avec chemin complet:
-- EXEC sp_get_lineage_export @p_uid='UID_START', @p_lnuid='LN_START', @p_edgdir='X', @p_sc='S';

-- 2. Limiter à 5 niveaux:
-- EXEC sp_get_lineage_export @p_uid='UID_START', @p_lnuid='LN_START', @p_edgdir='X', @p_sc='S', @p_max_level=5;

-- 3. Export CSV via SQLCMD (exécuter dans cmd):
-- sqlcmd -S SERVER -d lignage -Q "EXEC sp_export_lineage_csv 'UID_START','LN_START','X','S'" -s";" -W -o "C:\export\lineage.csv"

-- 4. Export via BCP:
-- bcp "EXEC lignage.dbo.sp_export_lineage_csv 'UID_START','LN_START','X','S'" queryout "C:\export\lineage.csv" -c -t";" -S SERVER -T
