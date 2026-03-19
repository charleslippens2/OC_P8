-- int_students_by_year.sql
-- Vue synthétique par année : effectifs et répartition genre.
--
-- Produit en une seule requête les indicateurs de la slide 8 :
--   • Inscriptions totales et étudiants distincts par année
--   • Répartition M / F / Non renseigné
--   • Taux de non-réponse au genre (qualité de collecte)
--   • % femmes parmi les répondants M/F (parité réelle)
--
-- Une ligne par année → format adapté au graphique barres slide 8.
-- Les indicateurs genre sont aussi dans int_gender_evolution
-- en format long (une ligne par genre), plus adapté au graphique empilé slide 9.

SELECT
    year_started,

    COUNT(*) AS nb_students,
    COUNT(DISTINCT USER_ID) AS nb_students_distincts,

    -- Décomposition par genre
    COUNT(CASE WHEN gender = 'M' THEN 1 END) AS nb_male,
    COUNT(CASE WHEN gender = 'F' THEN 1 END) AS nb_female,
    COUNT(CASE WHEN gender = 'Non renseigné' THEN 1 END) AS nb_nr,

    -- Taux de non-réponse : chute de 42% (2022) à 7% (2025)
    -- C'est un indicateur de qualité de collecte, pas un défaut des données
    ROUND(
        COUNT(CASE WHEN gender = 'Non renseigné' THEN 1 END) * 100.0 / COUNT(*), 1
    ) AS taux_non_reponse,

    -- % femmes parmi les répondants M/F uniquement
    -- Exclut les Non renseigné du dénominateur pour ne pas diluer le ratio
    -- Résultat : ~31% stable sur 4 ans (indépendant de la baisse des NR)
    ROUND(
        COUNT(CASE WHEN gender = 'F' THEN 1 END) * 100.0
        / NULLIF(
            COUNT(CASE WHEN gender = 'M' THEN 1 END)
            + COUNT(CASE WHEN gender = 'F' THEN 1 END), 0
        ), 1
    ) AS pct_female_among_declared

FROM {{ ref('stg_students') }}
GROUP BY year_started
ORDER BY year_started