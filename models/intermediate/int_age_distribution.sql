-- int_age_distribution.sql
-- Modèle intermédiaire : distribution par tranche d'âge et par année
--
-- Indicateurs produits :
--   5a. Distribution par tranche d'âge (% et rang)
--       Profil type de l'étudiant Data, évolution dans le temps
--       Identifier si le public rajeunit ou vieillit au fil des années
--   5b. Âge moyen approximatif par année
--       Estimation basée sur le point milieu de chaque tranche
--       Limite : "60 ans ou plus" codé à 65 (arbitraire)
--
-- Méthode : 3 CTE séparées pour lisibilité et testabilité
--   counts  → effectifs par tranche et par année
--   totals  → total annuel (pour calculer les pourcentages)
--   age_moyen → estimation âge moyen (point milieu de chaque tranche)
-- Puis jointure des 3 pour assembler le résultat final.
--
-- Le RANK() identifie automatiquement la tranche dominante
-- (pas codée en dur → s'adapte si le profil change).

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
    -- Total d'étudiants par année (dénominateur des pourcentages)
    SELECT
        year_started,
        SUM(nb_students) AS total_year
    FROM counts
    GROUP BY year_started
),

age_moyen AS (
    -- Âge moyen approximatif par année
    -- Méthode : point milieu de chaque tranche quinquennale
    -- Ex : "20-24 ans" → 22, "25-29 ans" → 27, etc.
    -- Limite : "60 ans ou plus" codé à 65 (pourrait être 70 ou 75)
    -- C'est une estimation, pas un calcul exact (données = tranches, pas âge réel)
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

    -- Pourcentage de la tranche d'âge dans l'année
    -- Ex : 30-34 ans = 24.1% en 2023
    ROUND(c.nb_students * 100.0 / t.total_year, 1) AS pct_of_year,

    -- Rang de la tranche dans l'année (1 = tranche la plus représentée)
    -- Utilisé par le mart pour récupérer automatiquement la top tranche
    RANK() OVER (
        PARTITION BY c.year_started
        ORDER BY c.nb_students DESC
    ) AS rang,

    -- Âge moyen approximatif (identique pour toutes les tranches d'une même année)
    -- Affiché en complément dans la présentation
    a.age_moyen_approx

FROM counts c
JOIN totals t ON c.year_started = t.year_started
JOIN age_moyen a ON c.year_started = a.year_started
ORDER BY c.year_started, c.nb_students DESC