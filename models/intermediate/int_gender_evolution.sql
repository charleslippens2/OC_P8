-- int_gender_evolution.sql
-- Évolution du genre par année — une ligne par modalité (M, F, Non renseigné).
--
-- Produit 3 indicateurs :
--   • Répartition M/F/NR par année → graphique empilé 100% slide 9
--   • % femmes parmi les répondants M/F → constat "~31% stable sur 4 ans"
--   • Taux de non-réponse → constat "42% en 2022 → 7% en 2025"
--
-- Différence avec int_students_by_year : ici chaque genre est sur une
-- ligne séparée (format long), adapté aux graphiques d'évolution.
-- int_students_by_year donne une ligne par année avec tout agrégé.

SELECT
    year_started,
    gender,

    COUNT(*) AS nb_students,

    -- Total annuel via window function (évite un CTE supplémentaire)
    SUM(COUNT(*)) OVER (PARTITION BY year_started) AS total_year,

    -- % de cette modalité sur le total de l'année (M + F + NR = 100%)
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (PARTITION BY year_started), 1
    ) AS pct_of_year,

    -- % parmi les répondants M/F uniquement (exclut Non renseigné)
    -- C'est cet indicateur qui donne le "vrai" ratio de parité :
    -- ~31% sur 4 ans, indépendamment de la chute des non-réponses
    -- NULL pour la ligne 'Non renseigné' (pas de sens)
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
        ELSE NULL
    END AS pct_among_declared

FROM {{ ref('stg_students') }}
GROUP BY year_started, gender
ORDER BY year_started, nb_students DESC