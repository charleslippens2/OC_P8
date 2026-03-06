-- int_region_distribution.sql
-- Modèle intermédiaire : distribution par région et par année
--
-- Indicateurs produits :
--   6. Top régions par année (dimension géographique)
--       Identifier les bassins de recrutement principaux
--   7. Concentration IDF vs province (dimension géographique)
--       Mesurer l'accessibilité territoriale de la formation
--       L'IDF concentre ~45% des étudiants vs ~18% de la population française
--
-- Méthode : CTE avec effectifs par région, jointure avec totaux annuels,
-- classification IDF/Province pour l'indicateur de concentration.

WITH counts AS (
    -- Effectifs par région et par année
    SELECT
        year_started,
        region,
        COUNT(*) AS nb_students
    FROM {{ ref('stg_students') }}
    GROUP BY year_started, region
),

totals AS (
    -- Total d'étudiants par année
    SELECT
        year_started,
        SUM(nb_students) AS total_year
    FROM counts
    GROUP BY year_started
)

SELECT
    c.year_started,
    c.region,
    c.nb_students,
    t.total_year,

    -- Pourcentage de la région dans l'année
    -- Ex : Île-de-France = 45,6% en 2022
    ROUND(c.nb_students * 100.0 / t.total_year, 1) AS pct_of_year,

    -- Indicateur 7 : Classification IDF vs Province
    -- Permet de mesurer la concentration géographique
    -- et l'accessibilité territoriale de la formation
    CASE
        WHEN c.region = 'Île-de-France' THEN 'IDF'
        ELSE 'Province'
    END AS zone,

    -- Indicateur 6 : Rang de la région (1 = top région de l'année)
    -- Identifie les principaux bassins de recrutement
    RANK() OVER (PARTITION BY c.year_started ORDER BY c.nb_students DESC) AS rang

FROM counts c
JOIN totals t ON c.year_started = t.year_started
ORDER BY c.year_started, c.nb_students DESC