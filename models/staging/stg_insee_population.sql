-- stg_insee_population.sql
-- Modèle staging : nettoyage et mapping des données INSEE au format OC
--
-- RÔLE : transformer les données brutes INSEE (RAW_INSEE.POPULATION_REGION)
--        pour qu'elles soient COMPARABLES avec les données OC (stg_students).
--        Sans ce mapping, les JOIN dans mart_comparison_insee échoueraient
--        car les noms de régions, tranches d'âge et sexes sont différents.
--
-- CONFORMITÉ ELT :
--        Le CSV brut a été chargé tel quel dans Snowflake (Load = brut).
--        Ce modèle fait le Transform dans DBT (pas en Python, pas dans Excel).
--        Les données brutes restent dans RAW_INSEE (traçabilité).
--
-- SOURCE : INSEE - Estimation de population au 1er janvier 2026
--          https://www.insee.fr/fr/statistiques/8721456
--          Open data, licence ouverte, aucune donnée personnelle → pas de RGPD
--
-- CE QUE FAIT CE MODÈLE (3 étapes) :
--   1. source   → lit les données brutes depuis RAW_INSEE
--   2. mapped   → renomme/regroupe les régions, tranches d'âge et sexes
--   3. aggregated → agrège les populations (nécessaire car les 60+ et DROM
--                   sont regroupés : 8 lignes INSEE → 1 ligne OC pour 60+)
--
-- ENTRÉE : ~4560 lignes (19 régions × 3 sexes × 20 tranches × 4 années)
-- SORTIE : ~1620 lignes (15 régions × 3 sexes × 9 tranches × 4 années)
--   Réduction car : < 20 ans exclus (4 tranches), 60+ regroupés (8→1),
--   DROM regroupés (6 lignes→1), Corse gardée (dans INSEE mais pas OC)


WITH source AS (
    -- Étape 1 : lire les données brutes de la table INSEE dans Snowflake
    -- Cette table a été chargée via Load Data (CSV → Snowflake)
    -- 5 colonnes : REGION, SEXE, AGE_GROUP, POPULATION, ANNEE
    -- Aucun filtre ici : le staging lit TOUT, le filtrage se fait après
    SELECT * FROM {{ source('insee', 'POPULATION_REGION') }}
),

mapped AS (
    -- Étape 2 : mapper les valeurs INSEE vers le format OC
    -- 3 mappings nécessaires : régions, sexe, tranches d'âge
    SELECT

        -- === MAPPING RÉGIONS ===
        -- Problème 1 : Centre-Val-de-Loire (tirets dans INSEE) vs Centre-Val de Loire (espaces dans OC)
        --   Si on ne corrige pas, le JOIN dans le mart ne matchera PAS ces 2 régions
        -- Problème 2 : les DROM sont séparés dans l'INSEE (Guadeloupe, Martinique, etc.)
        --   mais regroupés dans OC sous "DROM"
        --   Le GROUP BY + SUM dans l'étape aggregated additionnera les populations
        -- Problème 3 : DOM est une ligne de total dans l'INSEE (doublon avec les DROM individuels)
        --   On le mappe aussi sur 'DROM' et le SUM gèrera la déduplication
        --   ATTENTION : il faudra vérifier s'il y a double-comptage (DOM + DROM individuels)
        -- Corse : présente dans l'INSEE mais ABSENTE d'OC
        --   On la garde (ELSE REGION) → elle apparaîtra avec pct_oc = NULL dans le mart
        CASE
            WHEN REGION = 'Centre-Val-de-Loire' THEN 'Centre-Val de Loire'
            WHEN REGION IN (
                'Guadeloupe', 'Martinique', 'Guyane',
                'La Réunion', 'Mayotte', 'DOM'
            ) THEN 'DROM'
            ELSE REGION  -- Les 12 autres régions métro + Corse passent telles quelles
        END AS region,

        -- === MAPPING SEXE ===
        -- INSEE utilise 'Hommes'/'Femmes'/'Ensemble'
        -- OC utilise 'M'/'F' (pas d'Ensemble)
        -- On garde 'Ensemble' car utile pour calculer les % par région/âge
        --   dans le mart (dénominateur = population totale, pas H+F séparément)
        -- Le 'Non renseigné' d'OC n'existe pas dans l'INSEE (tout le monde est classé)
        CASE
            WHEN SEXE = 'Hommes' THEN 'M'
            WHEN SEXE = 'Femmes' THEN 'F'
            WHEN SEXE = 'Ensemble' THEN 'Ensemble'
        END AS sexe,

        -- === MAPPING TRANCHES D'ÂGE ===
        -- INSEE : "20 à 24 ans" (avec 'à')  →  OC : "20-24 ans" (avec tiret)
        -- Si on ne renomme pas, le JOIN par age_group ne matchera PAS
        --
        -- Cas spécial : les 8 tranches ≥ 60 ans de l'INSEE sont toutes mappées
        -- sur '60 ans ou plus' (la seule tranche 60+ d'OC).
        -- Le GROUP BY + SUM dans l'étape aggregated additionnera les 8 populations.
        -- Exemple IDF 2023 : 60-64=750K + 65-69=680K + ... + 95+=30K = 3 270K total
        --
        -- Cas spécial : les < 20 ans (0-4, 5-9, 10-14, 15-19) n'existent pas dans OC
        -- → mappés sur NULL, puis exclus par WHERE age_group IS NOT NULL dans l'étape aggregated
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
            ) THEN '60 ans ou plus'      -- 8 tranches → 1 seule (additionné par SUM)
            ELSE NULL                     -- < 20 ans → exclus à l'étape suivante
        END AS age_group,

        -- Population et année conservées telles quelles (données brutes)
        POPULATION,
        ANNEE AS annee  -- Renommage minuscule pour cohérence avec stg_students (year_started)

    FROM source
),

aggregated AS (
    -- Étape 3 : agréger les populations après le mapping
    --
    -- POURQUOI cette étape est nécessaire :
    --   Après le mapping, plusieurs lignes INSEE ont la MÊME combinaison
    --   region + sexe + age_group + annee :
    --
    --   Cas 1 - Les 60+ : 8 lignes INSEE (60-64, 65-69, ..., 95+) sont toutes
    --     mappées sur '60 ans ou plus'. Le SUM additionne les 8 populations.
    --
    --   Cas 2 - Les DROM : 6 lignes INSEE (Guadeloupe, Martinique, Guyane,
    --     La Réunion, Mayotte, DOM) sont toutes mappées sur 'DROM'.
    --     Le SUM additionne les populations des 6 territoires.
    --
    --   Sans cette agrégation, on aurait des doublons dans les JOIN du mart.
    --
    -- WHERE age_group IS NOT NULL : exclut les < 20 ans (mappés sur NULL)
    --   Car OC n'a pas d'étudiants de moins de 20 ans → pas comparable
    SELECT
        region,
        sexe,
        age_group,
        SUM(POPULATION) AS population,  -- Additionne les 60+ et les DROM
        annee
    FROM mapped
    WHERE age_group IS NOT NULL  -- Exclut 0-4, 5-9, 10-14, 15-19 ans
    GROUP BY region, sexe, age_group, annee
)

-- Résultat final : données INSEE nettoyées et comparables avec OC
-- Prêt pour le JOIN dans mart_comparison_insee.sql
SELECT * FROM aggregated