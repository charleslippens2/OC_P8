-- tests/assert_no_future_years.sql
-- Vérifie qu'aucune année n'est hors de la plage 2022-2025.
-- Détecte un import corrompu ou une saisie erronée (ex : 2026, 2021, 9999).
--
-- Complète le test YAML accepted_values(year) avec une approche SQL
-- explicite : le YAML vérifie une liste de valeurs autorisées,
-- ce test vérifie une plage. Les deux se renforcent.
--
-- 0 ligne retournée = PASS | 1+ ligne = FAIL (année hors périmètre)

SELECT *
FROM {{ ref('stg_students') }}
WHERE year_started > 2025
   OR year_started < 2022