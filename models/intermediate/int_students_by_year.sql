-- int_students_by_year.sql
-- Modèle intermédiaire : évolution globale par année
--
-- Indicateurs produits :
--   1. Nombre d'étudiants par année (dimension temporelle)
--       Mesurer la croissance/décroissance des inscriptions
--   2. Répartition H/F par année (dimension genre)
--       Mesurer la parité et son évolution
--   4. % femmes parmi les répondants (dimension genre)
--       Indicateur de parité excluant les non-réponses
--   3. Taux de non-réponse au genre (dimension genre)
--       Indicateur de qualité des données + possible signal sociétal


SELECT
    year_started,

    -- Indicateur 1 : Nombre d'étudiants par année (inscriptions)
    COUNT(*) AS nb_students,

    -- Nombre d'individus distincts (gestion des 568 réinscriptions)
    COUNT(DISTINCT USER_ID) AS nb_students_distincts,

    -- Indicateur 2 : Répartition H/F/NR par année
    COUNT(CASE WHEN gender = 'M' THEN 1 END) AS nb_male,
    COUNT(CASE WHEN gender = 'F' THEN 1 END) AS nb_female,
    COUNT(CASE WHEN gender = 'Non renseigné' THEN 1 END) AS nb_nr,

    -- Indicateur 3 : Taux de non-réponse au genre
    -- = nb_nr / total * 100
    -- Signal sociétal : les étudiants déclarent-ils plus ou moins leur genre au fil du temps ?
    ROUND(
        COUNT(CASE WHEN gender = 'Non renseigné' THEN 1 END) * 100.0 / COUNT(*), 1
    ) AS taux_non_reponse,

    -- Indicateur 4 : % femmes parmi les répondants uniquement
    -- Dénominateur = M + F (exclut 'Non renseigné')
    -- NULLIF évite la division par zéro si aucun répondant
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