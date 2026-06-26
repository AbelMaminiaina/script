-- ============================================
-- Procédure stockée: sp_get_lineage_all
-- Description: Récupère tous les successeurs ou prédécesseurs
--              de manière récursive (tous les niveaux)
-- Paramètres:
--   @p_uid    : Identifiant unique (correspond à edg1)
--   @p_lnuid  : Identifiant de lignage (correspond à edg2)
--   @p_edgdir : Direction edge (correspond à edg3)
--   @p_sc     : 'S' pour Successeur, 'P' pour Prédécesseur
-- ============================================
CREATE OR ALTER PROCEDURE sp_get_lineage_all
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1),
    @p_sc       CHAR(1)         -- 'S' = Successeur, 'P' = Prédécesseur
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_filter_edgdir CHAR(1);

    -- Déterminer la direction de filtre basée sur SC
    SET @v_filter_edgdir = CASE
        WHEN @p_sc = 'S' THEN 'O'
        WHEN @p_sc = 'P' THEN 'I'
        ELSE NULL
    END;

    -- Validation du paramètre SC
    IF @v_filter_edgdir IS NULL
    BEGIN
        RAISERROR('Paramètre SC invalide. Utilisez ''S'' pour Successeur ou ''P'' pour Prédécesseur.', 16, 1);
        RETURN;
    END

    -- CTE récursive pour parcourir tous les niveaux
    ;WITH LineageRecursive AS (
        -- Niveau 1 (ancre)
        SELECT
            1 AS niveau,
            dta1,
            dta2,
            dta3,
            dta4
        FROM lin_vis_edg
        WHERE edgdir = @v_filter_edgdir
          AND edg1 = @p_uid
          AND edg2 = @p_lnuid
          AND edg3 = @p_edgdir

        UNION ALL

        -- Niveaux suivants (récursion)
        SELECT
            lr.niveau + 1,
            lve.dta1,
            lve.dta2,
            lve.dta3,
            lve.dta4
        FROM lin_vis_edg lve
        INNER JOIN LineageRecursive lr
            ON lve.edg1 = lr.dta1
            AND lve.edg2 = lr.dta2
            AND lve.edg3 = lr.dta3
        WHERE lve.edgdir = @v_filter_edgdir
    )
    SELECT
        niveau,
        dta1,
        dta2,
        dta3,
        dta4
    FROM LineageRecursive
    ORDER BY niveau;

END;
GO

-- ============================================
-- Exemple d'utilisation:
-- ============================================
-- Pour obtenir tous les successeurs:
-- EXEC sp_get_lineage_all @p_uid = 'UID_START', @p_lnuid = 'LN_START', @p_edgdir = 'X', @p_sc = 'S';

-- Pour obtenir tous les prédécesseurs:
-- EXEC sp_get_lineage_all @p_uid = 'UID001', @p_lnuid = 'LN001', @p_edgdir = 'O', @p_sc = 'P';
