-- int_age_distribution.sql
-- Modèle intermédiaire : distribution par tranche d'âge et par année
--
-- Indicateur produit :
--   5. Distribution par tranche d'âge (dimension âge)
--       Profil type de l'étudiant Data, évolution dans le temps
--       Identifier si le public rajeunit ou vieillit au fil des années
--
-- Méthode : CTE pour calculer les effectifs par tranche,
-- puis jointure avec les totaux annuels pour obtenir les pourcentages.
-- Le RANK() identifie la tranche dominante de chaque année.

WITH counts AS (
    -- Effectifs par tranche d'âge et par année
    SELECT
        year_started,
        age_group,
        COUNT(*) AS nb_students
    FROM {{ ref('stg_students') }}
    GROUP BY year_started, age_group
),

totals AS (
    -- Total d'étudiants par année (pour calculer les pourcentages)
    SELECT
        year_started,
        SUM(nb_students) AS total_year
    FROM counts
    GROUP BY year_started
)

SELECT
    c.year_started,
    c.age_group,
    c.nb_students,
    t.total_year,

    -- Pourcentage de la tranche d'âge dans l'année
    -- Ex : 25-39 ans = 64% en 2022
    ROUND(c.nb_students * 100.0 / t.total_year, 1) AS pct_of_year,

    -- Rang de la tranche dans l'année (1 = tranche la plus représentée)
    -- Permet d'identifier rapidement la tranche dominante
    RANK() OVER (PARTITION BY c.year_started ORDER BY c.nb_students DESC) AS rang

FROM counts c
JOIN totals t ON c.year_started = t.year_started
ORDER BY c.year_started, c.nb_students DESC