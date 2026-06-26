-- ============================================
-- PROCEDURES D'ANALYSE DE LIGNAGE
-- ============================================

-- ============================================
-- 1. ANALYSE D'IMPACT
-- Quels éléments seront affectés si on modifie une source?
-- ============================================
CREATE OR ALTER PROCEDURE sp_impact_analysis
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ImpactCTE AS (
        SELECT
            CAST(@p_uid AS NVARCHAR(255)) AS src_uid,
            CAST(@p_lnuid AS NVARCHAR(255)) AS src_lnuid,
            CAST(@p_edgdir AS NVARCHAR(255)) AS src_edgdir,
            CAST(dta1 AS NVARCHAR(255)) AS impacted_uid,
            CAST(dta2 AS NVARCHAR(255)) AS impacted_lnuid,
            CAST(dta3 AS NVARCHAR(255)) AS impacted_edgdir,
            1 AS impact_level,
            CAST('DIRECT' AS NVARCHAR(20)) AS impact_type,
            CAST(dta1 + '|' + dta2 + '|' + dta3 AS NVARCHAR(MAX)) AS visited
        FROM lin_vis_edg
        WHERE edg1 = @p_uid AND edg2 = @p_lnuid AND edg3 = @p_edgdir
          AND edgdir = 'O'

        UNION ALL

        SELECT
            ic.src_uid,
            ic.src_lnuid,
            ic.src_edgdir,
            CAST(lve.dta1 AS NVARCHAR(255)),
            CAST(lve.dta2 AS NVARCHAR(255)),
            CAST(lve.dta3 AS NVARCHAR(255)),
            ic.impact_level + 1,
            CAST('INDIRECT' AS NVARCHAR(20)),
            ic.visited + ',' + lve.dta1 + '|' + lve.dta2 + '|' + lve.dta3
        FROM lin_vis_edg lve
        INNER JOIN ImpactCTE ic
            ON lve.edg1 = ic.impacted_uid
            AND lve.edg2 = ic.impacted_lnuid
            AND lve.edg3 = ic.impacted_edgdir
        WHERE lve.edgdir = 'O'
          AND ic.impact_level < 50
          AND CHARINDEX(lve.dta1 + '|' + lve.dta2 + '|' + lve.dta3, ic.visited) = 0
    )
    SELECT
        impacted_uid,
        impacted_lnuid,
        impacted_edgdir,
        impact_level,
        impact_type,
        COUNT(*) OVER() AS total_impacted
    FROM ImpactCTE
    ORDER BY impact_level, impacted_uid;
END;
GO

-- ============================================
-- 2. ANALYSE DE PROVENANCE (Root Cause)
-- D'où viennent les données?
-- ============================================
CREATE OR ALTER PROCEDURE sp_provenance_analysis
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ProvenanceCTE AS (
        SELECT
            CAST(@p_uid AS NVARCHAR(255)) AS target_uid,
            CAST(@p_lnuid AS NVARCHAR(255)) AS target_lnuid,
            CAST(@p_edgdir AS NVARCHAR(255)) AS target_edgdir,
            CAST(dta1 AS NVARCHAR(255)) AS source_uid,
            CAST(dta2 AS NVARCHAR(255)) AS source_lnuid,
            CAST(dta3 AS NVARCHAR(255)) AS source_edgdir,
            1 AS depth,
            CAST(@p_uid + ' <- ' + dta1 AS NVARCHAR(MAX)) AS lineage_path
        FROM lin_vis_edg
        WHERE edg1 = @p_uid AND edg2 = @p_lnuid AND edg3 = @p_edgdir
          AND edgdir = 'I'

        UNION ALL

        SELECT
            pc.target_uid,
            pc.target_lnuid,
            pc.target_edgdir,
            CAST(lve.dta1 AS NVARCHAR(255)),
            CAST(lve.dta2 AS NVARCHAR(255)),
            CAST(lve.dta3 AS NVARCHAR(255)),
            pc.depth + 1,
            pc.lineage_path + ' <- ' + lve.dta1
        FROM lin_vis_edg lve
        INNER JOIN ProvenanceCTE pc
            ON lve.edg1 = pc.source_uid
            AND lve.edg2 = pc.source_lnuid
            AND lve.edg3 = pc.source_edgdir
        WHERE lve.edgdir = 'I'
          AND pc.depth < 50
          AND CHARINDEX(lve.dta1, pc.lineage_path) = 0
    )
    SELECT
        source_uid,
        source_lnuid,
        source_edgdir,
        depth,
        lineage_path,
        CASE WHEN NOT EXISTS (
            SELECT 1 FROM lin_vis_edg
            WHERE edg1 = source_uid AND edg2 = source_lnuid AND edgdir = 'I'
        ) THEN 'SOURCE ORIGINE' ELSE '' END AS is_root
    FROM ProvenanceCTE
    ORDER BY depth, source_uid;
END;
GO

-- ============================================
-- 3. ANALYSE DE DEPENDANCES
-- ============================================

-- 3a. Dépendances directes
CREATE OR ALTER PROCEDURE sp_direct_dependencies
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        'SUCCESSEUR' AS relation,
        dta1 AS related_uid,
        dta2 AS related_lnuid,
        dta3 AS related_edgdir
    FROM lin_vis_edg
    WHERE edg1 = @p_uid AND edg2 = @p_lnuid AND edg3 = @p_edgdir
      AND edgdir = 'O'

    UNION ALL

    SELECT
        'PREDECESSEUR' AS relation,
        dta1,
        dta2,
        dta3
    FROM lin_vis_edg
    WHERE edg1 = @p_uid AND edg2 = @p_lnuid AND edg3 = @p_edgdir
      AND edgdir = 'I';
END;
GO

-- 3b. Noeuds critiques (plus de dépendants)
CREATE OR ALTER PROCEDURE sp_critical_nodes
    @p_top INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH NodeMetrics AS (
        SELECT
            edg1 AS node_uid,
            edg2 AS node_lnuid,
            edg3 AS node_edgdir,
            COUNT(*) AS dependents_count,
            SUM(CASE WHEN edgdir = 'O' THEN 1 ELSE 0 END) AS successors_count,
            SUM(CASE WHEN edgdir = 'I' THEN 1 ELSE 0 END) AS predecessors_count
        FROM lin_vis_edg
        GROUP BY edg1, edg2, edg3
    )
    SELECT TOP (@p_top)
        node_uid,
        node_lnuid,
        node_edgdir,
        dependents_count,
        successors_count,
        predecessors_count,
        'CRITIQUE' AS criticality
    FROM NodeMetrics
    ORDER BY dependents_count DESC;
END;
GO

-- ============================================
-- 4. ANALYSE DE QUALITE
-- ============================================

-- 4a. Noeuds orphelins (sans connexion)
CREATE OR ALTER PROCEDURE sp_orphan_nodes
AS
BEGIN
    SET NOCOUNT ON;

    -- Noeuds qui n'ont ni successeur ni prédécesseur
    SELECT DISTINCT
        uid,
        lnuid,
        edgdir,
        'ORPHELIN' AS status,
        CASE
            WHEN NOT EXISTS (
                SELECT 1 FROM lin_vis_edg b
                WHERE b.edg1 = a.dta1 AND b.edg2 = a.dta2 AND b.edg3 = a.dta3
            ) THEN 'FEUILLE (pas de successeur)'
            ELSE ''
        END AS leaf_status
    FROM lin_vis_edg a
    WHERE NOT EXISTS (
        SELECT 1 FROM lin_vis_edg b
        WHERE (b.dta1 = a.uid AND b.dta2 = a.lnuid AND b.dta3 = a.edgdir)
           OR (b.edg1 = a.dta1 AND b.edg2 = a.dta2 AND b.edg3 = a.dta3)
    );
END;
GO

-- 4b. Noeuds feuilles (terminus sans successeur)
CREATE OR ALTER PROCEDURE sp_leaf_nodes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        dta1 AS leaf_uid,
        dta2 AS leaf_lnuid,
        dta3 AS leaf_edgdir,
        'FEUILLE' AS node_type
    FROM lin_vis_edg a
    WHERE edgdir = 'O'
      AND NOT EXISTS (
        SELECT 1 FROM lin_vis_edg b
        WHERE b.edg1 = a.dta1 AND b.edg2 = a.dta2 AND b.edg3 = a.dta3
          AND b.edgdir = 'O'
    );
END;
GO

-- 4c. Noeuds racines (source sans prédécesseur)
CREATE OR ALTER PROCEDURE sp_root_nodes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        edg1 AS root_uid,
        edg2 AS root_lnuid,
        edg3 AS root_edgdir,
        'RACINE' AS node_type
    FROM lin_vis_edg a
    WHERE edgdir = 'O'
      AND NOT EXISTS (
        SELECT 1 FROM lin_vis_edg b
        WHERE b.dta1 = a.edg1 AND b.dta2 = a.edg2 AND b.dta3 = a.edg3
          AND b.edgdir = 'O'
    );
END;
GO

-- ============================================
-- 5. ANALYSE DE COMPLEXITE
-- ============================================

-- 5a. Profondeur maximale du lignage
CREATE OR ALTER PROCEDURE sp_lineage_depth
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1),
    @p_direction CHAR(1) = 'O'  -- O=successeurs, I=prédécesseurs
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH DepthCTE AS (
        SELECT
            CAST(dta1 AS NVARCHAR(255)) AS current_uid,
            CAST(dta2 AS NVARCHAR(255)) AS current_lnuid,
            CAST(dta3 AS NVARCHAR(255)) AS current_edgdir,
            1 AS depth
        FROM lin_vis_edg
        WHERE edg1 = @p_uid AND edg2 = @p_lnuid AND edg3 = @p_edgdir
          AND edgdir = @p_direction

        UNION ALL

        SELECT
            CAST(lve.dta1 AS NVARCHAR(255)),
            CAST(lve.dta2 AS NVARCHAR(255)),
            CAST(lve.dta3 AS NVARCHAR(255)),
            dc.depth + 1
        FROM lin_vis_edg lve
        INNER JOIN DepthCTE dc
            ON lve.edg1 = dc.current_uid
            AND lve.edg2 = dc.current_lnuid
            AND lve.edg3 = dc.current_edgdir
        WHERE lve.edgdir = @p_direction
          AND dc.depth < 100
    )
    SELECT
        @p_uid AS start_uid,
        @p_lnuid AS start_lnuid,
        @p_edgdir AS start_edgdir,
        CASE @p_direction WHEN 'O' THEN 'SUCCESSEURS' ELSE 'PREDECESSEURS' END AS direction,
        MAX(depth) AS max_depth,
        COUNT(DISTINCT current_uid + current_lnuid + current_edgdir) AS total_nodes
    FROM DepthCTE;
END;
GO

-- 5b. Statistiques globales de complexité
CREATE OR ALTER PROCEDURE sp_complexity_stats
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        'TOTAL LIGNES' AS metric,
        CAST(COUNT(*) AS NVARCHAR(50)) AS value
    FROM lin_vis_edg

    UNION ALL

    SELECT
        'NOEUDS UNIQUES (edg)',
        CAST(COUNT(DISTINCT edg1 + '|' + edg2 + '|' + edg3) AS NVARCHAR(50))
    FROM lin_vis_edg

    UNION ALL

    SELECT
        'NOEUDS UNIQUES (dta)',
        CAST(COUNT(DISTINCT dta1 + '|' + ISNULL(dta2,'') + '|' + ISNULL(dta3,'')) AS NVARCHAR(50))
    FROM lin_vis_edg

    UNION ALL

    SELECT
        'LIENS SUCCESSEURS',
        CAST(COUNT(*) AS NVARCHAR(50))
    FROM lin_vis_edg WHERE edgdir = 'O'

    UNION ALL

    SELECT
        'LIENS PREDECESSEURS',
        CAST(COUNT(*) AS NVARCHAR(50))
    FROM lin_vis_edg WHERE edgdir = 'I';
END;
GO

-- ============================================
-- 6. METRIQUES FAN-IN / FAN-OUT / CENTRALITE
-- ============================================

-- 6a. Fan-in (nombre de sources alimentant un noeud)
CREATE OR ALTER PROCEDURE sp_fan_in
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @p_uid AS node_uid,
        @p_lnuid AS node_lnuid,
        @p_edgdir AS node_edgdir,
        COUNT(*) AS fan_in,
        STRING_AGG(dta1 + ',' + dta2 + ',' + dta3, ' | ') AS sources
    FROM lin_vis_edg
    WHERE edg1 = @p_uid AND edg2 = @p_lnuid AND edg3 = @p_edgdir
      AND edgdir = 'I';
END;
GO

-- 6b. Fan-out (nombre de cibles alimentées par un noeud)
CREATE OR ALTER PROCEDURE sp_fan_out
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @p_uid AS node_uid,
        @p_lnuid AS node_lnuid,
        @p_edgdir AS node_edgdir,
        COUNT(*) AS fan_out,
        STRING_AGG(dta1 + ',' + dta2 + ',' + dta3, ' | ') AS targets
    FROM lin_vis_edg
    WHERE edg1 = @p_uid AND edg2 = @p_lnuid AND edg3 = @p_edgdir
      AND edgdir = 'O';
END;
GO

-- 6c. Centralité (noeuds les plus connectés)
CREATE OR ALTER PROCEDURE sp_centrality
    @p_top INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AllNodes AS (
        SELECT edg1 AS uid, edg2 AS lnuid, edg3 AS edgdir FROM lin_vis_edg
        UNION
        SELECT dta1, dta2, dta3 FROM lin_vis_edg WHERE dta1 IS NOT NULL
    ),
    NodeConnections AS (
        SELECT
            n.uid,
            n.lnuid,
            n.edgdir,
            (SELECT COUNT(*) FROM lin_vis_edg WHERE edg1 = n.uid AND edg2 = n.lnuid AND edg3 = n.edgdir AND edgdir = 'O') AS fan_out,
            (SELECT COUNT(*) FROM lin_vis_edg WHERE edg1 = n.uid AND edg2 = n.lnuid AND edg3 = n.edgdir AND edgdir = 'I') AS fan_in
        FROM AllNodes n
    )
    SELECT TOP (@p_top)
        uid,
        lnuid,
        edgdir,
        fan_in,
        fan_out,
        fan_in + fan_out AS total_connections,
        CASE
            WHEN fan_in + fan_out >= 5 THEN 'HAUTE'
            WHEN fan_in + fan_out >= 2 THEN 'MOYENNE'
            ELSE 'BASSE'
        END AS centrality_level
    FROM NodeConnections
    WHERE fan_in + fan_out > 0
    ORDER BY total_connections DESC;
END;
GO

-- ============================================
-- 7. RAPPORT COMPLET
-- ============================================
CREATE OR ALTER PROCEDURE sp_lineage_report
    @p_uid      NVARCHAR(100),
    @p_lnuid    NVARCHAR(100),
    @p_edgdir   CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== RAPPORT DE LIGNAGE ===';
    PRINT 'Noeud: ' + @p_uid + ', ' + @p_lnuid + ', ' + @p_edgdir;
    PRINT '';

    PRINT '--- Fan-In (Sources) ---';
    EXEC sp_fan_in @p_uid, @p_lnuid, @p_edgdir;

    PRINT '--- Fan-Out (Cibles) ---';
    EXEC sp_fan_out @p_uid, @p_lnuid, @p_edgdir;

    PRINT '--- Profondeur Successeurs ---';
    EXEC sp_lineage_depth @p_uid, @p_lnuid, @p_edgdir, 'O';

    PRINT '--- Profondeur Predecesseurs ---';
    EXEC sp_lineage_depth @p_uid, @p_lnuid, @p_edgdir, 'I';

    PRINT '--- Dependances Directes ---';
    EXEC sp_direct_dependencies @p_uid, @p_lnuid, @p_edgdir;
END;
GO

-- ============================================
-- EXEMPLES D'UTILISATION
-- ============================================

-- Analyse d'impact
-- EXEC sp_impact_analysis @p_uid='B', @p_lnuid='LN', @p_edgdir='O';

-- Analyse de provenance
-- EXEC sp_provenance_analysis @p_uid='C', @p_lnuid='LN', @p_edgdir='O';

-- Dépendances directes
-- EXEC sp_direct_dependencies @p_uid='B', @p_lnuid='LN', @p_edgdir='O';

-- Noeuds critiques (top 10)
-- EXEC sp_critical_nodes @p_top=10;

-- Noeuds orphelins
-- EXEC sp_orphan_nodes;

-- Noeuds feuilles
-- EXEC sp_leaf_nodes;

-- Noeuds racines
-- EXEC sp_root_nodes;

-- Profondeur du lignage
-- EXEC sp_lineage_depth @p_uid='START', @p_lnuid='LN', @p_edgdir='X', @p_direction='O';

-- Statistiques de complexité
-- EXEC sp_complexity_stats;

-- Fan-in / Fan-out
-- EXEC sp_fan_in @p_uid='B', @p_lnuid='LN', @p_edgdir='O';
-- EXEC sp_fan_out @p_uid='B', @p_lnuid='LN', @p_edgdir='O';

-- Centralité
-- EXEC sp_centrality @p_top=10;

-- Rapport complet
-- EXEC sp_lineage_report @p_uid='B', @p_lnuid='LN', @p_edgdir='O';
