-- mart_sociodemographic.sql
-- Synthèse annuelle : une ligne par année avec tous les indicateurs clés.
--
-- Assemble les 4 modèles intermédiaires par JOIN — aucun recalcul.
-- Chaque couche garde son rôle : staging nettoie, intermediate calcule, mart assemble.
--
-- Résultat : 4 lignes (2022-2025) avec effectifs, genre, top région, top âge, % IDF.
-- Matérialisation : table (résultat final, lu par la direction).

WITH by_year AS (
    -- Socle : effectifs, répartition genre, taux NR, % femmes parmi répondants
    SELECT * FROM {{ ref('int_students_by_year') }}
),

top_region AS (
    -- Région n°1 de chaque année (via RANK dans l'intermediate)
    -- Pas codé en dur : si une autre région dépasse l'IDF, ça s'adapte
    SELECT
        year_started,
        region AS top_region,
        pct_of_year AS pct_top_region
    FROM {{ ref('int_region_distribution') }}
    WHERE rang = 1
),

top_age AS (
    -- Tranche d'âge n°1 de chaque année
    SELECT
        year_started,
        age_group AS top_age_group,
        pct_of_year AS pct_top_age
    FROM {{ ref('int_age_distribution') }}
    WHERE rang = 1
),

idf AS (
    -- % IDF par année — indicateur d'accessibilité territoriale
    -- Filtré par nom (pas par rang) car c'est spécifiquement l'IDF
    -- qui intéresse la direction
    SELECT
        year_started,
        pct_of_year AS pct_idf
    FROM {{ ref('int_region_distribution') }}
    WHERE region = 'Île-de-France'
)

-- LEFT JOIN : si une année manque une donnée (improbable), la ligne est conservée
SELECT
    y.*,
    r.top_region,
    r.pct_top_region,
    i.pct_idf,
    a.top_age_group,
    a.pct_top_age
FROM by_year y
LEFT JOIN top_region r ON y.year_started = r.year_started
LEFT JOIN top_age a ON y.year_started = a.year_started
LEFT JOIN idf i ON y.year_started = i.year_started
ORDER BY y.year_started