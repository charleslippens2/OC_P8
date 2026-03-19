-- int_region_distribution.sql
-- Répartition géographique par année.
--
-- Produit :
--   • % et rang de chaque région par année (backup oral pour l'évolution IDF)
--   • Classification IDF / Province pour mesurer la concentration territoriale
--
-- Constat clé : l'IDF concentre ~45% des étudiants vs ~17% de la population.
-- Ce modèle permet de vérifier si cette concentration évolue par année
-- (pic à 54% en 2023, retour à ~41% en 2024-2025).

WITH counts AS (
    SELECT
        year_started,
        region,
        COUNT(*) AS nb_students
    FROM {{ ref('stg_students') }}
    GROUP BY year_started, region
),

totals AS (
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
    ROUND(c.nb_students * 100.0 / t.total_year, 1) AS pct_of_year,

    -- IDF vs Province — pour mesurer la concentration géographique
    CASE
        WHEN c.region = 'Île-de-France' THEN 'IDF'
        ELSE 'Province'
    END AS zone,

    -- Rang 1 = région avec le plus d'étudiants dans l'année
    RANK() OVER (PARTITION BY c.year_started ORDER BY c.nb_students DESC) AS rang

FROM counts c
JOIN totals t ON c.year_started = t.year_started
ORDER BY c.year_started, c.nb_students DESC