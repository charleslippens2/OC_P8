-- int_gender_evolution.sql
-- Modèle intermédiaire : évolution détaillée du genre par année
--
-- Indicateurs produits :
--   2. Répartition H/F par année (dimension genre)
--       Mesurer la parité et son évolution année par année
--   3. % femmes parmi les répondants (dimension genre)
--       Indicateur de parité excluant les non-réponses
--   4. Taux de non-réponse au genre (dimension genre)
--       Qualité des données + signal sociétal
--
-- Différence avec int_students_by_year :
--   Ce modèle détaille chaque modalité de genre (M, F, Non renseigné)
--   sur des lignes séparées, ce qui facilite la création de graphiques
--   d'évolution (une courbe par genre).


SELECT
    year_started,
    gender,

    -- Effectif de cette modalité de genre pour l'année
    COUNT(*) AS nb_students,

    -- Total de l'année (window function pour garder le détail par genre)
    SUM(COUNT(*)) OVER (PARTITION BY year_started) AS total_year,

    -- Pourcentage de cette modalité sur le total de l'année
    -- Ex : M = 50,4%, F = 22,7%, Non renseigné = 26,8%
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (PARTITION BY year_started), 1
    ) AS pct_of_year,

    -- Pourcentage parmi les répondants uniquement (excl. Non renseigné)
    -- Utile pour calculer la vraie parité H/F
    -- Ex : si M=50,4% et F=22,7% du total, parmi les répondants
    --       F = 22,7 / (50,4+22,7) * 100 = 31% environ
    CASE
        WHEN gender != 'Non renseigné' THEN
            ROUND(
                COUNT(*) * 100.0
                / NULLIF(
                    SUM(CASE WHEN gender != 'Non renseigné'
                        THEN COUNT(*) ELSE 0 END)
                    OVER (PARTITION BY year_started), 0
                ), 1
            )
        ELSE NULL  -- Pas de sens pour 'Non renseigné'
    END AS pct_among_declared

FROM {{ ref('stg_students') }}
GROUP BY year_started, gender
ORDER BY year_started, nb_students DESC