-- ============================================
-- Procédure stockée: sp_detect_cycles
-- Description: Détecte les cycles dans les données de lignage
-- Paramètres:
--   @p_edgdir : 'O' pour successeurs, 'I' pour prédécesseurs, NULL pour tous
-- ============================================
CREATE OR ALTER PROCEDURE sp_detect_cycles
    @p_edgdir CHAR(1) = NULL    -- NULL = tous, 'O' = successeurs, 'I' = prédécesseurs
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH DetectCycles AS (
        -- Point de départ: tous les noeuds (edg1, edg2, edg3)
        SELECT
            CAST(edg1 AS NVARCHAR(255)) AS start_node1,
            CAST(edg2 AS NVARCHAR(255)) AS start_node2,
            CAST(edg3 AS NVARCHAR(255)) AS start_node3,
            CAST(dta1 AS NVARCHAR(255)) AS current_node1,
            CAST(dta2 AS NVARCHAR(255)) AS current_node2,
            CAST(dta3 AS NVARCHAR(255)) AS current_node3,
            edgdir,
            1 AS niveau,
            CAST(edg1 + ',' + edg2 + ',' + edg3 + ' -> ' + dta1 + ',' + dta2 + ',' + dta3 AS NVARCHAR(MAX)) AS chemin,
            CASE
                WHEN dta1 = edg1 AND dta2 = edg2 AND dta3 = edg3 THEN 1
                ELSE 0
            END AS is_cycle
        FROM lin_vis_edg
        WHERE (@p_edgdir IS NULL OR edgdir = @p_edgdir)

        UNION ALL

        -- Récursion: suivre les liens
        SELECT
            dc.start_node1,
            dc.start_node2,
            dc.start_node3,
            CAST(lve.dta1 AS NVARCHAR(255)),
            CAST(lve.dta2 AS NVARCHAR(255)),
            CAST(lve.dta3 AS NVARCHAR(255)),
            dc.edgdir,
            dc.niveau + 1,
            dc.chemin + ' -> ' + lve.dta1 + ',' + lve.dta2 + ',' + lve.dta3,
            CASE
                WHEN lve.dta1 = dc.start_node1
                 AND lve.dta2 = dc.start_node2
                 AND lve.dta3 = dc.start_node3
                THEN 1
                ELSE 0
            END
        FROM lin_vis_edg lve
        INNER JOIN DetectCycles dc
            ON lve.edg1 = dc.current_node1
            AND lve.edg2 = dc.current_node2
            AND lve.edg3 = dc.current_node3
            AND lve.edgdir = dc.edgdir
        WHERE dc.is_cycle = 0
          AND dc.niveau < 50
          AND (@p_edgdir IS NULL OR lve.edgdir = @p_edgdir)
          -- Permettre retour au start_node (cycle) mais pas aux noeuds intermédiaires
          AND (
              (lve.dta1 = dc.start_node1 AND lve.dta2 = dc.start_node2 AND lve.dta3 = dc.start_node3)
              OR CHARINDEX(lve.dta1 + ',' + lve.dta2 + ',' + lve.dta3, dc.chemin) = 0
          )
    )
    SELECT DISTINCT
        start_node1 AS cycle_node1,
        start_node2 AS cycle_node2,
        start_node3 AS cycle_node3,
        edgdir,
        niveau AS cycle_length,
        chemin + ' -> [RETOUR]' AS cycle_path
    FROM DetectCycles
    WHERE is_cycle = 1
    ORDER BY cycle_length, start_node1;

END;
GO

-- ============================================
-- Vue pour lister tous les cycles
-- ============================================
CREATE OR ALTER VIEW v_all_cycles AS
WITH DetectCycles AS (
    SELECT
        uid AS start_uid,
        lnuid AS start_lnuid,
        edgdir AS start_edgdir,
        CAST(dta1 AS NVARCHAR(255)) AS current_uid,
        CAST(dta2 AS NVARCHAR(255)) AS current_lnuid,
        CAST(dta3 AS NVARCHAR(255)) AS current_edgdir,
        1 AS niveau,
        CAST(uid + ',' + lnuid + ',' + edgdir AS NVARCHAR(MAX)) AS chemin,
        0 AS is_cycle
    FROM lin_vis_edg

    UNION ALL

    SELECT
        dc.start_uid,
        dc.start_lnuid,
        dc.start_edgdir,
        CAST(lve.dta1 AS NVARCHAR(255)),
        CAST(lve.dta2 AS NVARCHAR(255)),
        CAST(lve.dta3 AS NVARCHAR(255)),
        dc.niveau + 1,
        dc.chemin + ' -> ' + lve.uid + ',' + lve.lnuid + ',' + lve.edgdir,
        CASE
            WHEN lve.dta1 = dc.start_uid
             AND lve.dta2 = dc.start_lnuid
             AND lve.dta3 = dc.start_edgdir
            THEN 1
            ELSE 0
        END
    FROM lin_vis_edg lve
    INNER JOIN DetectCycles dc
        ON lve.edg1 = dc.current_uid
        AND lve.edg2 = dc.current_lnuid
        AND lve.edg3 = dc.current_edgdir
    WHERE dc.is_cycle = 0
      AND dc.niveau < 50
      AND (
          CHARINDEX(lve.uid + ',' + lve.lnuid + ',' + lve.edgdir, dc.chemin) = 0
          OR (lve.dta1 = dc.start_uid AND lve.dta2 = dc.start_lnuid AND lve.dta3 = dc.start_edgdir)
      )
)
SELECT DISTINCT
    start_uid AS cycle_start_uid,
    start_lnuid AS cycle_start_lnuid,
    start_edgdir AS cycle_start_edgdir,
    niveau AS cycle_length,
    chemin + ' -> [CYCLE]' AS cycle_path
FROM DetectCycles
WHERE is_cycle = 1;
GO

-- ============================================
-- Fonction pour vérifier si un noeud est dans un cycle
-- ============================================
CREATE OR ALTER FUNCTION fn_is_in_cycle(
    @p_uid NVARCHAR(100),
    @p_lnuid NVARCHAR(100),
    @p_edgdir CHAR(1)
)
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT = 0;

    ;WITH DetectCycle AS (
        SELECT
            CAST(dta1 AS NVARCHAR(255)) AS current_uid,
            CAST(dta2 AS NVARCHAR(255)) AS current_lnuid,
            CAST(dta3 AS NVARCHAR(255)) AS current_edgdir,
            1 AS niveau,
            0 AS is_cycle
        FROM lin_vis_edg
        WHERE uid = @p_uid AND lnuid = @p_lnuid AND edgdir = @p_edgdir

        UNION ALL

        SELECT
            CAST(lve.dta1 AS NVARCHAR(255)),
            CAST(lve.dta2 AS NVARCHAR(255)),
            CAST(lve.dta3 AS NVARCHAR(255)),
            dc.niveau + 1,
            CASE
                WHEN lve.dta1 = @p_uid AND lve.dta2 = @p_lnuid AND lve.dta3 = @p_edgdir
                THEN 1
                ELSE 0
            END
        FROM lin_vis_edg lve
        INNER JOIN DetectCycle dc
            ON lve.edg1 = dc.current_uid
            AND lve.edg2 = dc.current_lnuid
            AND lve.edg3 = dc.current_edgdir
        WHERE dc.is_cycle = 0
          AND dc.niveau < 50
    )
    SELECT @result = MAX(is_cycle) FROM DetectCycle;

    RETURN ISNULL(@result, 0);
END;
GO

-- ============================================
-- Exemples d'utilisation:
-- ============================================

-- 1. Détecter tous les cycles:
-- EXEC sp_detect_cycles;

-- 2. Détecter les cycles dans les successeurs uniquement:
-- EXEC sp_detect_cycles @p_edgdir = 'O';

-- 3. Détecter les cycles dans les prédécesseurs uniquement:
-- EXEC sp_detect_cycles @p_edgdir = 'I';

-- 4. Utiliser la vue:
-- SELECT * FROM v_all_cycles;

-- 5. Vérifier si un noeud est dans un cycle:
-- SELECT dbo.fn_is_in_cycle('X', 'LN', 'O') AS is_in_cycle;
