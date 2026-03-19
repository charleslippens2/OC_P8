-- mart_comparison_insee.sql
-- Croisement du profil OC avec la population française (INSEE).
--
-- C'est la contextualisation qui donne du sens aux chiffres OC :
-- sans l'INSEE, "31% de femmes" ne dit rien.
-- Avec : "31% vs 52% = déficit de 21 points".
--
-- 3 comparaisons dans une seule table (UNION ALL) :
--   • Région : 13 régions OC + Corse (NULL côté OC) → slide 11 + 12
--   • Genre  : 1 ligne (% femmes OC vs INSEE) → slide 12
--   • Âge    : 9 tranches → slide 10 + 12
--
-- Choix techniques :
--   - Lit les staging directement, pas les intermédiaires. Les intermédiaires
--     sont par année, ici on veut le profil OC global toutes années confondues.
--   - INSEE filtré sur 2023 (dernières données définitives, 2024-2025 = estimations).
--   - FULL OUTER JOIN : conserve les régions/tranches présentes d'un seul côté
--     (ex : Corse dans l'INSEE mais pas dans OC → pct_oc = NULL).
--
-- Résultat : ~25 lignes | Matérialisation : table


-- COMPARAISON PAR RÉGION
-- IDF surreprésentée ×2,6, toutes les autres régions sous-représentées

WITH oc_regions AS (
    SELECT
        region,
        COUNT(*) AS nb_oc,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_oc
    FROM {{ ref('stg_students') }}
    GROUP BY region
),

insee_regions AS (
    -- sexe = 'Ensemble' pour le total, annee = 2023 pour les données définitives
    SELECT
        region,
        SUM(population) AS pop_insee,
        ROUND(SUM(population) * 100.0 / SUM(SUM(population)) OVER (), 1) AS pct_insee
    FROM {{ ref('stg_insee_population') }}
    WHERE sexe = 'Ensemble' AND annee = 2023
    GROUP BY region
),

comp_region AS (
    -- FULL OUTER JOIN : Corse apparaît avec pct_oc = NULL (aucun étudiant OC)
    -- ecart_pts : + = surreprésenté OC, - = sous-représenté
    -- ratio : facteur multiplicatif (IDF = 2,62)
    SELECT
        COALESCE(o.region, i.region) AS region,
        o.nb_oc,
        o.pct_oc,
        i.pop_insee,
        i.pct_insee,
        ROUND(o.pct_oc - i.pct_insee, 1) AS ecart_pts,
        ROUND(o.pct_oc / NULLIF(i.pct_insee, 0), 2) AS ratio
    FROM oc_regions o
    FULL OUTER JOIN insee_regions i ON o.region = i.region
),


-- COMPARAISON PAR GENRE
-- 31% femmes OC vs 52% INSEE = déficit de 21 points

oc_gender AS (
    -- % femmes parmi les répondants M/F (exclut Non renseigné)
    -- Inclure les NR diluerait le taux à ~23% au lieu de 31%
    SELECT
        ROUND(
            COUNT(CASE WHEN gender = 'F' THEN 1 END) * 100.0
            / NULLIF(COUNT(CASE WHEN gender IN ('M', 'F') THEN 1 END), 0),
        1) AS pct_f_oc
    FROM {{ ref('stg_students') }}
),

insee_gender AS (
    -- % femmes dans la population française
    -- 'Ensemble' dans l'INSEE = total H+F (pas un 3ème genre)
    SELECT
        ROUND(
            SUM(CASE WHEN sexe = 'F' THEN population END) * 100.0
            / SUM(CASE WHEN sexe = 'Ensemble' THEN population END),
        1) AS pct_f_insee
    FROM {{ ref('stg_insee_population') }}
    WHERE annee = 2023
),

comp_gender AS (
    -- CROSS JOIN implicite (1 ligne × 1 ligne)
    SELECT
        pct_f_oc,
        pct_f_insee,
        ROUND(pct_f_oc - pct_f_insee, 1) AS ecart_pts
    FROM oc_gender, insee_gender
),


-- COMPARAISON PAR ÂGE
-- 25-39 ans surreprésentés ×2,7 (profil reconversion)

oc_age AS (
    SELECT
        age_group,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_oc
    FROM {{ ref('stg_students') }}
    GROUP BY age_group
),

insee_age AS (
    -- Le staging INSEE a déjà exclu les < 20 ans et agrégé les 60+
    SELECT
        age_group,
        ROUND(SUM(population) * 100.0 / SUM(SUM(population)) OVER (), 1) AS pct_insee
    FROM {{ ref('stg_insee_population') }}
    WHERE sexe = 'Ensemble' AND annee = 2023
    GROUP BY age_group
),

comp_age AS (
    SELECT
        COALESCE(o.age_group, i.age_group) AS age_group,
        o.pct_oc,
        i.pct_insee,
        ROUND(o.pct_oc - i.pct_insee, 1) AS ecart_pts
    FROM oc_age o
    FULL OUTER JOIN insee_age i ON o.age_group = i.age_group
)


-- ASSEMBLAGE des 3 dimensions dans une seule table
-- Colonne 'dimension' pour filtrer (WHERE dimension = 'region')

SELECT 'region' AS dimension, region AS detail,
    pct_oc, pct_insee, ecart_pts, ratio
FROM comp_region

UNION ALL

SELECT 'genre', 'Femmes',
    pct_f_oc, pct_f_insee, ecart_pts, NULL
FROM comp_gender

UNION ALL

SELECT 'age', age_group,
    pct_oc, pct_insee, ecart_pts, NULL
FROM comp_age

ORDER BY dimension, ecart_pts DESC