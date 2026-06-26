-- ============================================
-- Création de la table lin_vis_edg
-- ============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'lin_vis_edg')
BEGIN
    CREATE TABLE lin_vis_edg (
        uid     NVARCHAR(100) NOT NULL,
        lnuid   NVARCHAR(100) NOT NULL,
        edgdir  CHAR(1) NOT NULL CHECK (edgdir IN ('I', 'O')),
        dta1    NVARCHAR(255),
        dta2    NVARCHAR(255),
        dta3    NVARCHAR(255),
        dta4    NVARCHAR(255),
        edg1    NVARCHAR(255),
        edg2    NVARCHAR(255),
        edg3    NVARCHAR(255),
        edg4    NVARCHAR(255),
        CONSTRAINT PK_lin_vis_edg PRIMARY KEY (uid, lnuid, edgdir)
    );
    PRINT 'Table lin_vis_edg créée.';
END
ELSE
BEGIN
    PRINT 'Table lin_vis_edg existe déjà.';
END
GO

-- ============================================
-- Insertion de données de test
-- ============================================
DELETE FROM lin_vis_edg;

-- Données avec edgdir = 'O' (Output/Successeurs)
-- dta1-4 sont successeurs de edg1-4
INSERT INTO lin_vis_edg (uid, lnuid, edgdir, dta1, dta2, dta3, dta4, edg1, edg2, edg3, edg4)
VALUES
('UID001', 'LN001', 'O', 'SUCC_A1', 'SUCC_A2', 'SUCC_A3', 'SUCC_A4', 'SRC_A1', 'SRC_A2', 'SRC_A3', 'SRC_A4'),
('UID002', 'LN001', 'O', 'SUCC_B1', 'SUCC_B2', 'SUCC_B3', 'SUCC_B4', 'SRC_B1', 'SRC_B2', 'SRC_B3', 'SRC_B4'),
('UID001', 'LN002', 'O', 'SUCC_C1', 'SUCC_C2', 'SUCC_C3', 'SUCC_C4', 'SRC_C1', 'SRC_C2', 'SRC_C3', 'SRC_C4');

-- Données avec edgdir = 'I' (Input/Prédécesseurs)
-- dta1-4 sont prédécesseurs de edg1-4
INSERT INTO lin_vis_edg (uid, lnuid, edgdir, dta1, dta2, dta3, dta4, edg1, edg2, edg3, edg4)
VALUES
('UID001', 'LN001', 'I', 'PRED_A1', 'PRED_A2', 'PRED_A3', 'PRED_A4', 'TGT_A1', 'TGT_A2', 'TGT_A3', 'TGT_A4'),
('UID002', 'LN001', 'I', 'PRED_B1', 'PRED_B2', 'PRED_B3', 'PRED_B4', 'TGT_B1', 'TGT_B2', 'TGT_B3', 'TGT_B4'),
('UID001', 'LN002', 'I', 'PRED_C1', 'PRED_C2', 'PRED_C3', 'PRED_C4', 'TGT_C1', 'TGT_C2', 'TGT_C3', 'TGT_C4');

PRINT 'Données de test insérées.';
GO

-- ============================================
-- Afficher les données
-- ============================================
PRINT '';
PRINT '=== Contenu de la table lin_vis_edg ===';
SELECT * FROM lin_vis_edg;
GO

-- ============================================
-- Test de la procédure stockée
-- ============================================
PRINT '';
PRINT '=== Test 1: Successeurs pour UID001, LN001 (SC=S) ===';
EXEC sp_get_lineage @p_uid = 'UID001', @p_lnuid = 'LN001', @p_sc = 'S';
GO

PRINT '';
PRINT '=== Test 2: Prédécesseurs pour UID001, LN001 (SC=P) ===';
EXEC sp_get_lineage @p_uid = 'UID001', @p_lnuid = 'LN001', @p_sc = 'P';
GO

PRINT '';
PRINT '=== Test 3: Successeurs pour UID001, LN002 (SC=S) ===';
EXEC sp_get_lineage @p_uid = 'UID001', @p_lnuid = 'LN002', @p_sc = 'S';
GO
