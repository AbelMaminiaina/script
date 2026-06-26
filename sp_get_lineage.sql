-- ============================================
-- Procédure stockée: sp_get_lineage
-- Description: Récupère les successeurs ou prédécesseurs
--              edg1=uid, edg2=lnuid, edg3=edgdir, edg4=autre
-- Paramètres:
--   @p_uid    : Identifiant unique (correspond à edg1)
--   @p_lnuid  : Identifiant de lignage (correspond à edg2)
--   @p_edgdir : Direction edge (correspond à edg3)
--   @p_sc     : 'S' pour Successeur, 'P' pour Prédécesseur
-- ============================================
CREATE OR ALTER PROCEDURE sp_get_lineage
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1),
    @p_sc       CHAR(1)         -- 'S' = Successeur, 'P' = Prédécesseur
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_filter_edgdir CHAR(1);

    -- Déterminer la direction de filtre basée sur SC
    -- S (Successeur) -> edgdir = 'O' (Output)
    -- P (Prédécesseur) -> edgdir = 'I' (Input)
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

    -- Retourner dta1, dta2, dta3, dta4
    -- où edg1=uid, edg2=lnuid, edg3=edgdir
    SELECT
        dta1,
        dta2,
        dta3,
        dta4
    FROM lin_vis_edg
    WHERE edgdir = @v_filter_edgdir
      AND edg1 = @p_uid
      AND edg2 = @p_lnuid
      AND edg3 = @p_edgdir;

END;
GO

-- ============================================
-- Exemple d'utilisation:
-- ============================================
-- Pour obtenir les successeurs (edgdir='O') où edg1='UID001', edg2='LN001', edg3='I':
-- EXEC sp_get_lineage @p_uid = 'UID001', @p_lnuid = 'LN001', @p_edgdir = 'I', @p_sc = 'S';

-- Pour obtenir les prédécesseurs (edgdir='I') où edg1='UID001', edg2='LN001', edg3='O':
-- EXEC sp_get_lineage @p_uid = 'UID001', @p_lnuid = 'LN001', @p_edgdir = 'O', @p_sc = 'P';
