-- mart_sociodemographic.sql
-- Modèle mart : synthèse annuelle pour la direction pédagogique
--
-- RÔLE : assembler les résultats des 4 modèles intermédiaires
--        en une seule table de 4 lignes (une par année).
--        Ce mart NE RECALCULE RIEN : il fait uniquement des JOIN.
--
-- POURQUOI : Marie-Neige et la direction veulent un tableau unique
--            avec tous les indicateurs clés par année, pas 4 tables séparées.
--            Ce mart alimente la slide 14 (synthèse et recommandations).
--
-- RÉSULTAT : 4 lignes × ~13 colonnes
--   | year | nb_students | nb_distincts | nb_male | nb_female | nb_nr |
--   | taux_non_reponse | pct_female_among_declared |
--   | top_region | pct_top_region | pct_idf | top_age_group | pct_top_age |
--
-- MATÉRIALISATION : table (pas vue) car c'est le résultat final,
--   lu par la direction. Une table est plus performante à lire.
--
-- CHOIX D'ARCHITECTURE :
--   Le mart lit les intermédiaires (pas le staging).
--   Si le mart refaisait les GROUP BY depuis le staging,
--   les intermédiaires ne serviraient à rien.
--   Chaque couche a un rôle unique : staging nettoie, intermediate calcule, mart assemble.

WITH by_year AS (
    -- Récupère TOUTES les colonnes de int_students_by_year
    -- = effectifs, genre (nb_male, nb_female, nb_nr), taux_non_reponse, pct_female
    -- C'est le socle du mart : une ligne par année avec les indicateurs de base
    SELECT * FROM {{ ref('int_students_by_year') }}
),

top_region AS (
    -- Récupère la RÉGION N°1 de chaque année (celle avec le plus d'étudiants)
    -- WHERE rang = 1 : utilise le RANK() calculé dans int_region_distribution
    -- Pas codé en dur ("Île-de-France") : si demain une autre région domine, ça s'adapte
    -- Exemple : 2022 → Île-de-France (45.2%), 2023 → Île-de-France (44.8%)
    SELECT
        year_started,
        region AS top_region,          -- Nom de la région dominante
        pct_of_year AS pct_top_region  -- Son pourcentage (ex: 45.2%)
    FROM {{ ref('int_region_distribution') }}
    WHERE rang = 1
),

top_age AS (
    -- Récupère la TRANCHE D'ÂGE N°1 de chaque année
    -- Même logique : WHERE rang = 1 depuis int_age_distribution
    -- Exemple : 2022 → 30-34 ans (24.1%), 2023 → 25-29 ans (22.5%)
    SELECT
        year_started,
        age_group AS top_age_group,  -- Tranche dominante
        pct_of_year AS pct_top_age   -- Son pourcentage
    FROM {{ ref('int_age_distribution') }}
    WHERE rang = 1
),

idf AS (
    -- Récupère le POURCENTAGE IDF de chaque année
    -- Indicateur d'accessibilité territoriale (IDF = ~45% vs 18% en population)
    -- Filtré sur 'Île-de-France' spécifiquement (pas le rang, le nom exact)
    -- POURQUOI : c'est la métrique la plus parlante pour la direction
    --   "45% de nos étudiants sont en IDF" → enjeu accessibilité
    SELECT
        year_started,
        pct_of_year AS pct_idf  -- Ex: 45.2% en 2022
    FROM {{ ref('int_region_distribution') }}
    WHERE region = 'Île-de-France'
)

-- ASSEMBLAGE FINAL : une ligne par année avec tout
-- LEFT JOIN (pas INNER) : si une année n'a pas de données IDF
-- ou pas de top région (improbable mais sécuritaire), la ligne n'est pas perdue
SELECT
    -- Depuis int_students_by_year (toutes les colonnes) :
    --   year_started, nb_students, nb_students_distincts,
    --   nb_male, nb_female, nb_nr,
    --   taux_non_reponse, pct_female_among_declared
    y.*,

    -- Depuis int_region_distribution (top région) :
    r.top_region,        -- Ex: 'Île-de-France'
    r.pct_top_region,    -- Ex: 45.2

    -- Depuis int_region_distribution (IDF spécifiquement) :
    i.pct_idf,           -- Ex: 45.2 (souvent = pct_top_region car IDF est souvent 1ère)

    -- Depuis int_age_distribution (top tranche) :
    a.top_age_group,     -- Ex: '30-34 ans'
    a.pct_top_age        -- Ex: 24.1

FROM by_year y
LEFT JOIN top_region r ON y.year_started = r.year_started
LEFT JOIN top_age a ON y.year_started = a.year_started
LEFT JOIN idf i ON y.year_started = i.year_started
ORDER BY y.year_started