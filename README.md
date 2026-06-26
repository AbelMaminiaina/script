# Lineage SQL Server

Ensemble de procédures stockées SQL Server pour l'analyse de lignage de données (Data Lineage).

## Table de données

```sql
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
    edg4    NVARCHAR(255)
);
```

### Structure

| Colonne | Description |
|---------|-------------|
| `uid, lnuid, edgdir` | Clé unique de la ligne |
| `edgdir` | Direction: `O` (Output/Successeur) ou `I` (Input/Prédécesseur) |
| `edg1, edg2, edg3, edg4` | Identifiants source (uid, lnuid, edgdir, autre) |
| `dta1, dta2, dta3, dta4` | Identifiants cible (uid, lnuid, edgdir, autre) |

## Installation

```bash
sqlcmd -S "SERVEUR" -E -d lignage -i create_table_and_test.sql
sqlcmd -S "SERVEUR" -E -d lignage -i sp_get_lineage.sql
sqlcmd -S "SERVEUR" -E -d lignage -i sp_get_lineage_level2.sql
sqlcmd -S "SERVEUR" -E -d lignage -i sp_get_lineage_all.sql
sqlcmd -S "SERVEUR" -E -d lignage -i sp_get_lineage_export.sql
sqlcmd -S "SERVEUR" -E -d lignage -i sp_detect_cycles.sql
sqlcmd -S "SERVEUR" -E -d lignage -i sp_lineage_analytics.sql
```

## Procédures de navigation

### sp_get_lineage
Récupère les successeurs ou prédécesseurs de niveau 1.

```sql
-- Successeurs directs
EXEC sp_get_lineage @p_uid='UID001', @p_lnuid='LN001', @p_edgdir='O', @p_sc='S';

-- Prédécesseurs directs
EXEC sp_get_lineage @p_uid='UID001', @p_lnuid='LN001', @p_edgdir='O', @p_sc='P';
```

### sp_get_lineage_level2
Récupère les successeurs ou prédécesseurs de niveau 2.

```sql
EXEC sp_get_lineage_level2 @p_uid='UID001', @p_lnuid='LN001', @p_edgdir='O', @p_sc='S';
```

### sp_get_lineage_all
Récupère tous les niveaux de manière récursive.

```sql
EXEC sp_get_lineage_all @p_uid='START', @p_lnuid='LN', @p_edgdir='X', @p_sc='S';
```

### sp_get_lineage_export
Version améliorée avec:
- Chemin complet de navigation
- Protection anti-cycle
- Limite de niveaux configurable

```sql
-- Avec chemin complet
EXEC sp_get_lineage_export @p_uid='START', @p_lnuid='LN', @p_edgdir='X', @p_sc='S';

-- Limiter à 5 niveaux
EXEC sp_get_lineage_export @p_uid='START', @p_lnuid='LN', @p_edgdir='X', @p_sc='S', @p_max_level=5;
```

### sp_export_lineage_csv
Export CSV compatible Excel.

```bash
sqlcmd -S "SERVEUR" -E -d lignage -Q "EXEC sp_export_lineage_csv 'START','LN','X','S'" -s";" -W -o "lineage.csv"
```

## Détection de cycles

### sp_detect_cycles
Détecte les cycles dans les données.

```sql
-- Tous les cycles
EXEC sp_detect_cycles;

-- Cycles successeurs uniquement
EXEC sp_detect_cycles @p_edgdir='O';

-- Cycles prédécesseurs uniquement
EXEC sp_detect_cycles @p_edgdir='I';
```

### v_all_cycles
Vue listant tous les cycles.

```sql
SELECT * FROM v_all_cycles;
```

### fn_is_in_cycle
Vérifie si un noeud est dans un cycle.

```sql
SELECT dbo.fn_is_in_cycle('Y', 'LN', 'O') AS is_in_cycle;
```

## Procédures d'analyse

### Analyse d'impact
Quels éléments seront affectés si on modifie une source?

```sql
EXEC sp_impact_analysis @p_uid='UID001', @p_lnuid='LN001', @p_edgdir='O';
```

### Analyse de provenance
D'où viennent les données?

```sql
EXEC sp_provenance_analysis @p_uid='UID004', @p_lnuid='LN001', @p_edgdir='O';
```

### Dépendances directes

```sql
EXEC sp_direct_dependencies @p_uid='B', @p_lnuid='LN', @p_edgdir='O';
```

### Noeuds critiques
Top N des noeuds avec le plus de dépendants.

```sql
EXEC sp_critical_nodes @p_top=10;
```

### Noeuds orphelins

```sql
EXEC sp_orphan_nodes;
```

### Noeuds feuilles (terminus)

```sql
EXEC sp_leaf_nodes;
```

### Noeuds racines (sources)

```sql
EXEC sp_root_nodes;
```

### Profondeur du lignage

```sql
-- Profondeur successeurs
EXEC sp_lineage_depth @p_uid='START', @p_lnuid='LN', @p_edgdir='X', @p_direction='O';

-- Profondeur prédécesseurs
EXEC sp_lineage_depth @p_uid='UID004', @p_lnuid='LN001', @p_edgdir='O', @p_direction='I';
```

### Statistiques de complexité

```sql
EXEC sp_complexity_stats;
```

**Résultat:**
| Métrique | Description |
|----------|-------------|
| TOTAL LIGNES | Nombre total de lignes |
| NOEUDS UNIQUES (edg) | Noeuds sources uniques |
| NOEUDS UNIQUES (dta) | Noeuds cibles uniques |
| LIENS SUCCESSEURS | Nombre de liens O |
| LIENS PREDECESSEURS | Nombre de liens I |

### Fan-In / Fan-Out

```sql
-- Nombre de sources alimentant un noeud
EXEC sp_fan_in @p_uid='B', @p_lnuid='LN', @p_edgdir='O';

-- Nombre de cibles alimentées par un noeud
EXEC sp_fan_out @p_uid='B', @p_lnuid='LN', @p_edgdir='O';
```

### Centralité
Top N des noeuds les plus connectés.

```sql
EXEC sp_centrality @p_top=10;
```

### Rapport complet

```sql
EXEC sp_lineage_report @p_uid='B', @p_lnuid='LN', @p_edgdir='O';
```

## Fichiers

| Fichier | Description |
|---------|-------------|
| `create_table_and_test.sql` | Création table et données de test |
| `sp_get_lineage.sql` | Navigation niveau 1 |
| `sp_get_lineage_level2.sql` | Navigation niveau 2 |
| `sp_get_lineage_all.sql` | Navigation récursive |
| `sp_get_lineage_export.sql` | Export avec anti-cycle |
| `sp_detect_cycles.sql` | Détection de cycles |
| `sp_lineage_analytics.sql` | Procédures d'analyse |

## Licence

MIT
