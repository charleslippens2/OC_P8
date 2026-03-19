# Projet P8 — Analyse sociodémographique des étudiants Data OC

Analyse de l'évolution du profil sociodémographique des étudiants des parcours Data d'OpenClassrooms (2022-2025), comparé à la population française (INSEE).

## Objectif

Produire des indicateurs exploitables pour la direction pédagogique sur 3 dimensions : genre, âge, géographie. Les données OC sont contextualisées avec les estimations de population INSEE pour mesurer les écarts (surreprésentation IDF, déficit de parité, profil reconversion).

## Stack technique

- **Snowflake** — entrepôt de données (base OC_P8)
- **dbt Cloud** — transformations SQL, tests, documentation
- **GitHub** — versioning du code
- **Python (openpyxl)** — prétraitement du fichier Excel INSEE avant chargement
- **INSEE** — données externes de population (open data)

## Sources de données

| Source | Table Snowflake | Description |
|--------|----------------|-------------|
| OpenClassrooms | `OC_P8.RAW.STUDENTS` | 4647 inscriptions, 6 variables, 2022-2025 |
| INSEE | `OC_P8.RAW_INSEE.POPULATION_REGION` | Population par région, sexe, âge quinquennal |

## Architecture du pipeline
```
Sources (RAW)          Staging (stg_)         Intermediate (int_)       Marts
─────────────          ──────────────         ───────────────────       ─────
STUDENTS          →    stg_students      →    int_students_by_year  →  mart_sociodemographic
                                         →    int_gender_evolution  →  mart_livrable_csv
                                         →    int_age_distribution
                                         →    int_region_distribution
POPULATION_REGION →    stg_insee_population ─────────────────────────→ mart_comparison_insee
                                                                   →  mart_livrable_csv
```

## Modèles

| Couche | Modèle | Rôle |
|--------|--------|------|
| staging | `stg_students` | Nettoyage : TRIM, genre vide → 'Non renseigné', filtre USER_ID NULL |
| staging | `stg_insee_population` | Harmonisation : régions, sexe (M/F/Ensemble), regroupement 60+ et DROM |
| intermediate | `int_students_by_year` | Effectifs et répartition genre par année |
| intermediate | `int_gender_evolution` | Évolution M/F/NR par année (format long) |
| intermediate | `int_age_distribution` | Distribution âge par année + âge moyen estimé |
| intermediate | `int_region_distribution` | Répartition géographique par année + rang |
| mart | `mart_comparison_insee` | Croisement OC global vs INSEE 2023 sur 3 dimensions |
| mart | `mart_sociodemographic` | Synthèse annuelle (top région, top âge, % IDF) |
| mart | `mart_livrable_csv` | Export consolidé pour le livrable CSV (un bloc par slide) |

## Tests

6 tests automatisés, exécutés à chaque `dbt build` :

| Test | Type | Ce qu'il vérifie |
|------|------|-----------------|
| `not_null (USER_ID)` | YAML | Aucune ligne sans identifiant |
| `not_null (gender)` | YAML | Plus de NULL après nettoyage |
| `accepted_values (gender)` | YAML | Uniquement M, F, Non renseigné |
| `accepted_values (year)` | YAML | Années 2022-2025 uniquement |
| `assert_unique_student_year` | Custom SQL | Unicité USER_ID + année (568 réinscriptions OK, pas de vrai doublon) |
| `assert_percentages_sum_100` | Custom SQL | Somme des % = 100% par année (tolérance arrondis) |
| `assert_region_pct_sum_100` | Custom SQL | Idem pour les régions |
| `assert_no_future_years` | Custom SQL | Pas d'année hors plage 2022-2025 |

## Conformité RGPD

- **Pseudonymisation** : USER_ID hashé en amont par OC
- **Donnée sensible** : genre traité au titre de l'art. 9 RGPD, finalité égalité des chances
- **Pas d'imputation** : les genres vides restent 'Non renseigné' (droit de non-réponse)
- **Minimisation** : 6 colonnes, tranches d'âge (pas l'âge exact), régions (pas d'adresse)
- **Résultats agrégés** : aucune donnée individuelle en sortie des marts

## Exécution
```bash
# Exécuter le pipeline complet (modèles + tests)
dbt build

# Modèles seuls
dbt run

# Tests seuls
dbt test

# Documentation et lineage
dbt docs generate
```

## Export du livrable CSV

Dans Snowflake (Snowsight) :
```sql
SELECT * FROM OC_P8.DBT_CLIPPENS.MART_LIVRABLE_CSV
ORDER BY slide, rang;
```
Puis bouton Download → CSV.

## Structure du repo
```
models/
  staging/
    stg_students.sql
    stg_insee_population.sql
    _staging__sources.yml
    _staging__models.yml
  intermediate/
    int_students_by_year.sql
    int_gender_evolution.sql
    int_age_distribution.sql
    int_region_distribution.sql
    _int__models.yml
  marts/
    mart_comparison_insee.sql
    mart_sociodemographic.sql
    mart_livrable_csv.sql
    _marts__models.yml
tests/
  assert_unique_student_year.sql
  assert_percentages_sum_100.sql
  assert_region_pct_sum_100.sql
  assert_no_future_years.sql
dbt_project.yml
README.md
```