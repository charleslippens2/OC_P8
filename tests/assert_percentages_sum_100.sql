-- tests/assert_percentages_sum_100.sql
--
-- TEST CUSTOM : les pourcentages par tranche d'âge totalisent ~100% par année
--
-- CONTEXTE :
--   Le modèle int_age_distribution calcule un pct_of_year pour chaque tranche.
--   Si on additionne les 9 tranches d'une année, le total doit faire 100%.
--   Un total de 98% ou 103% signifierait un bug dans le calcul de pourcentage
--   (mauvais dénominateur, lignes manquantes, doublons).
--
-- CE QUE CE TEST VÉRIFIE :
--   Pour chaque année, SUM(pct_of_year) est entre 99 et 101.
--   La marge 99-101 tolère les arrondis (ROUND à 1 décimale).
--   Exemple : 9 tranches arrondies individuellement peuvent donner 99.9 ou 100.1.
--
-- POURQUOI C'EST IMPORTANT :
--   C'est une vérification de COHÉRENCE MATHÉMATIQUE.
--   Si les % ne font pas 100, les graphiques de la présentation seront faux.
--   L'évaluateur pourrait remarquer que les barres empilées ne font pas 100%.
--
-- RÉSULTAT ATTENDU : 0 lignes retournées = PASS
-- SI ÉCHEC : une année a un total de % aberrant → vérifier int_age_distribution

SELECT
    year_started,
    ROUND(SUM(pct_of_year), 0) AS total_pct
FROM {{ ref('int_age_distribution') }}
GROUP BY year_started
HAVING total_pct < 99 OR total_pct > 101
-- Retourne les années dont le total des % est incohérent
-- Ex : 2023 | 97 → il manque 3 points, une tranche est peut-être mal calculée