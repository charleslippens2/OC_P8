-- tests/assert_region_pct_sum_100.sql
--
-- TEST CUSTOM : les pourcentages par région totalisent ~100% par année
--
-- CONTEXTE :
--   Même logique que assert_percentages_sum_100 mais pour les régions.
--   Le modèle int_region_distribution calcule un pct_of_year pour chaque région.
--   La somme des 13 régions (+ DROM) doit faire 100% par année.
--
-- CE QUE CE TEST VÉRIFIE :
--   Pour chaque année, SUM(pct_of_year) est entre 99 et 101.
--   Si une région est manquante ou comptée deux fois, le total sera ≠ 100.
--
-- POURQUOI EN PLUS DU TEST SUR L'ÂGE :
--   Les deux modèles (âge et région) font des calculs de % indépendants.
--   Un bug dans l'un n'implique pas un bug dans l'autre.
--   On vérifie les deux séparément pour être sûr.
--
-- RÉSULTAT ATTENDU : 0 lignes retournées = PASS
-- SI ÉCHEC : vérifier int_region_distribution (région manquante ? doublon ?)

SELECT
    year_started,
    ROUND(SUM(pct_of_year), 0) AS total_pct
FROM {{ ref('int_region_distribution') }}
GROUP BY year_started
HAVING total_pct < 99 OR total_pct > 101
-- Retourne les années dont le total des % régions est incohérent