-- ============================================
-- Procédure stockée: sp_get_lineage_level2
-- Description: Récupère les successeurs ou prédécesseurs niveau 2
--              (successeurs des successeurs / prédécesseurs des prédécesseurs)
-- Paramètres:
--   @p_uid    : Identifiant unique (correspond à edg1)
--   @p_lnuid  : Identifiant de lignage (correspond à edg2)
--   @p_edgdir : Direction edge (correspond à edg3)
--   @p_sc     : 'S' pour Successeur, 'P' pour Prédécesseur
-- ============================================
CREATE OR ALTER PROCEDURE sp_get_lineage_level2
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

    -- Niveau 2: Successeurs des successeurs / Prédécesseurs des prédécesseurs
    -- dta1=uid, dta2=lnuid, dta3=edgdir du niveau 1
    SELECT
        lvl2.dta1,
        lvl2.dta2,
        lvl2.dta3,
        lvl2.dta4
    FROM lin_vis_edg lvl1
    INNER JOIN lin_vis_edg lvl2
        ON lvl2.edg1 = lvl1.dta1
        AND lvl2.edg2 = lvl1.dta2
        AND lvl2.edg3 = lvl1.dta3
        AND lvl2.edgdir = @v_filter_edgdir
    WHERE lvl1.edgdir = @v_filter_edgdir
      AND lvl1.edg1 = @p_uid
      AND lvl1.edg2 = @p_lnuid
      AND lvl1.edg3 = @p_edgdir;

END;
GO

-- ============================================
-- Exemple d'utilisation:
-- ============================================
-- Pour obtenir les successeurs niveau 2:
-- EXEC sp_get_lineage_level2 @p_uid = 'UID001', @p_lnuid = 'LN001', @p_edgdir = 'O', @p_sc = 'S';

-- Pour obtenir les prédécesseurs niveau 2:
-- EXEC sp_get_lineage_level2 @p_uid = 'UID001', @p_lnuid = 'LN001', @p_edgdir = 'O', @p_sc = 'P';
