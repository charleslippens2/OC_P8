-- stg_insee_population.sql
-- Nettoyage des données INSEE pour les rendre comparables avec les données OC.
-- Sans ce mapping, les JOIN dans mart_comparison_insee échoueraient
-- (noms de régions, tranches d'âge et codes sexe différents entre les 2 sources).
--
-- Approche ELT : le CSV brut a été chargé tel quel dans Snowflake (RAW_INSEE).
-- Tout le nettoyage se fait ici dans dbt, pas en Python ni Excel.
--
-- 3 étapes :
--   1. source     → lecture brute (~4560 lignes)
--   2. mapped     → harmonisation régions, sexe, tranches d'âge
--   3. aggregated → regroupement des 60+ (8 tranches → 1) et des DROM (6 → 1)
--
-- Résultat : ~1620 lignes (15 régions × 3 sexes × 9 tranches × 4 années)
--
-- Source INSEE : Estimations de population au 1er janvier 2026
-- https://www.insee.fr/fr/statistiques/8721456
-- Open data, aucune donnée personnelle, pas de RGPD.


WITH source AS (
    SELECT * FROM {{ source('insee', 'POPULATION_REGION') }}
),

mapped AS (
    SELECT

        -- Régions : 3 problèmes à résoudre
        --  • Centre-Val-de-Loire (tirets INSEE) vs Centre-Val de Loire (espaces OC)
        --  • DROM séparés dans l'INSEE, regroupés en un seul "DROM" côté OC
        --  • Corse : présente dans l'INSEE mais absente d'OC → gardée, apparaîtra avec pct_oc = NULL
        CASE
            WHEN REGION = 'Centre-Val-de-Loire' THEN 'Centre-Val de Loire'
            WHEN REGION IN (
                'Guadeloupe', 'Martinique', 'Guyane',
                'La Réunion', 'Mayotte', 'DOM'
            ) THEN 'DROM'
            ELSE REGION
        END AS region,

        -- Sexe : INSEE utilise les libellés complets, OC utilise M/F
        -- On garde 'Ensemble' (= total H+F) pour les calculs de % dans le mart
        CASE
            WHEN SEXE = 'Hommes' THEN 'M'
            WHEN SEXE = 'Femmes' THEN 'F'
            WHEN SEXE = 'Ensemble' THEN 'Ensemble'
        END AS sexe,

        -- Tranches d'âge : "20 à 24 ans" (INSEE) → "20-24 ans" (format OC)
        -- Les 8 tranches ≥ 60 ans → regroupées en "60 ans ou plus" (seule tranche OC)
        -- Les < 20 ans → NULL, exclus à l'étape suivante (pas d'étudiants < 20 dans OC)
        CASE
            WHEN AGE_GROUP = '20 à 24 ans' THEN '20-24 ans'
            WHEN AGE_GROUP = '25 à 29 ans' THEN '25-29 ans'
            WHEN AGE_GROUP = '30 à 34 ans' THEN '30-34 ans'
            WHEN AGE_GROUP = '35 à 39 ans' THEN '35-39 ans'
            WHEN AGE_GROUP = '40 à 44 ans' THEN '40-44 ans'
            WHEN AGE_GROUP = '45 à 49 ans' THEN '45-49 ans'
            WHEN AGE_GROUP = '50 à 54 ans' THEN '50-54 ans'
            WHEN AGE_GROUP = '55 à 59 ans' THEN '55-59 ans'
            WHEN AGE_GROUP IN (
                '60 à 64 ans', '65 à 69 ans', '70 à 74 ans',
                '75 à 79 ans', '80 à 84 ans', '85 à 89 ans',
                '90 à 94 ans', '95 ans et plus'
            ) THEN '60 ans ou plus'
            ELSE NULL
        END AS age_group,

        POPULATION,
        ANNEE AS annee

    FROM source
),

aggregated AS (
    -- Agrégation nécessaire car le mapping a créé des doublons intentionnels :
    --  • 8 lignes 60+ → 1 seule "60 ans ou plus" (SUM des populations)
    --  • 6 lignes DROM → 1 seul "DROM" (SUM des populations)
    -- WHERE exclut les < 20 ans (NULL après mapping)
    SELECT
        region,
        sexe,
        age_group,
        SUM(POPULATION) AS population,
        annee
    FROM mapped
    WHERE age_group IS NOT NULL
    GROUP BY region, sexe, age_group, annee
)

SELECT * FROM aggregated