-- int_age_distribution.sql
-- Distribution par tranche d'âge et par année.
--
-- Produit :
--   • % et rang de chaque tranche par année (slide 10 en global, backup oral par année)
--   • Âge moyen estimé par année (estimation par point milieu de tranche)
--
-- Architecture : 3 CTE pour séparer les responsabilités
--   counts    → effectifs bruts par tranche/année
--   totals    → total annuel (dénominateur des %)
--   age_moyen → estimation âge moyen (point milieu)
--
-- Le RANK() identifie la tranche dominante automatiquement —
-- pas codé en dur, s'adapte si le profil évolue.
--
-- Limite connue : la tranche "60 ans ou plus" est codée à 65 pour
-- le calcul de l'âge moyen. Arbitraire (pourrait être 70 ou 75),
-- mais l'impact est faible car cette tranche ne représente que 1,6%.

WITH counts AS (
    SELECT
        year_started,
        age_group,
        COUNT(*) AS nb_students
    FROM {{ ref('stg_students') }}
    GROUP BY year_started, age_group
),

totals AS (
    SELECT
        year_started,
        SUM(nb_students) AS total_year
    FROM counts
    GROUP BY year_started
),

age_moyen AS (
    -- Estimation par point milieu de chaque tranche quinquennale
    -- Ce n'est pas un âge exact — les données source sont des tranches, pas des dates de naissance
    SELECT
        year_started,
        ROUND(AVG(
            CASE age_group
                WHEN '20-24 ans' THEN 22
                WHEN '25-29 ans' THEN 27
                WHEN '30-34 ans' THEN 32
                WHEN '35-39 ans' THEN 37
                WHEN '40-44 ans' THEN 42
                WHEN '45-49 ans' THEN 47
                WHEN '50-54 ans' THEN 52
                WHEN '55-59 ans' THEN 57
                WHEN '60 ans ou plus' THEN 65
            END
        ), 1) AS age_moyen_approx
    FROM {{ ref('stg_students') }}
    GROUP BY year_started
)

SELECT
    c.year_started,
    c.age_group,
    c.nb_students,
    t.total_year,
    ROUND(c.nb_students * 100.0 / t.total_year, 1) AS pct_of_year,

    -- Rang 1 = tranche la plus représentée de l'année
    RANK() OVER (
        PARTITION BY c.year_started
        ORDER BY c.nb_students DESC
    ) AS rang,

    a.age_moyen_approx

FROM counts c
JOIN totals t ON c.year_started = t.year_started
JOIN age_moyen a ON c.year_started = a.year_started
ORDER BY c.year_started, c.nb_students DESC