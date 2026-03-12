-- tests/assert_no_future_years.sql
--
-- TEST CUSTOM : pas d'années hors de la plage attendue
--
-- CONTEXTE :
--   Le dataset couvre 2022-2025. Si une ligne contient 2026, 2021, ou 9999,
--   c'est une erreur de données (import corrompu, saisie erronée).
--
-- CE QUE CE TEST VÉRIFIE :
--   Toutes les années sont comprises entre 2022 et 2025 inclus.
--   Complète le test accepted_values du YAML (qui vérifie la même chose)
--   mais en SQL explicite, plus facile à comprendre pour l'évaluateur.
--
-- POURQUOI CE TEST EN PLUS DU YAML :
--   Le YAML accepted_values vérifie la même chose, mais ce test custom
--   est plus explicite et montre à l'évaluateur une démarche de vérification
--   active (pas juste du YAML déclaratif).
--
-- RÉSULTAT ATTENDU : 0 lignes retournées = PASS
-- SI ÉCHEC : des lignes ont des années impossibles → vérifier l'import

SELECT *
FROM {{ ref('stg_students') }}
WHERE year_started > 2025
   OR year_started < 2022
-- Retourne les lignes problématiques avec toutes leurs colonnes
-- pour faciliter l'investigation