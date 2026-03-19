-- tests/assert_unique_student_year.sql
-- Vérifie l'unicité de la combinaison USER_ID + année.
--
-- Le test 'unique' standard sur USER_ID seul échoue (568 résultats)
-- car 568 étudiants sont inscrits sur plusieurs années — c'est normal.
-- Ce test vérifie qu'un même étudiant n'a pas 2 lignes la MÊME année.
-- Si ça passe : les 568 sont bien des réinscriptions (années différentes).
-- Si ça échoue : vrai doublon technique à investiguer.
--
-- 0 ligne retournée = PASS | 1+ ligne = FAIL

SELECT
    USER_ID,
    year_started,
    COUNT(*) AS nb_occurrences
FROM {{ ref('stg_students') }}
GROUP BY USER_ID, year_started
HAVING COUNT(*) > 1