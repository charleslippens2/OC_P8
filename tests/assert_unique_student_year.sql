-- tests/assert_unique_student_year.sql
--
-- TEST CUSTOM : unicité de la combinaison USER_ID + année
--
-- CONTEXTE :
--   Le test 'unique' de base sur USER_ID échoue avec 568 résultats
--   car 568 étudiants sont inscrits sur plusieurs années (réinscriptions).
--   Ce n'est PAS une erreur : un étudiant inscrit en 2022 et 2023 = 2 lignes légitimes.
--
-- CE QUE CE TEST VÉRIFIE :
--   La combinaison USER_ID + year_started est unique.
--   Un même étudiant ne peut PAS avoir 2 lignes pour la MÊME année.
--   Si ce test échoue = vrai doublon technique (erreur d'import ou bug).
--   Si ce test passe = les 568 sont bien des réinscriptions (années différentes).
--
-- RÉSULTAT ATTENDU : 0 lignes retournées = PASS
-- SI ÉCHEC : des USER_ID ont plusieurs lignes pour la même année → investiguer

SELECT
    USER_ID,
    year_started,
    COUNT(*) AS nb_occurrences
FROM {{ ref('stg_students') }}
GROUP BY USER_ID, year_started
HAVING COUNT(*) > 1
-- Si des lignes apparaissent ici, c'est un vrai problème de données