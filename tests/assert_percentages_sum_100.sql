-- tests/assert_percentages_sum_100.sql
-- Vérifie que les % par tranche d'âge totalisent ~100% pour chaque année.
-- Un total de 97% ou 103% signalerait un bug dans int_age_distribution
-- (mauvais dénominateur, lignes manquantes, doublons).
--
-- Marge 99-101 : tolère les arrondis (ROUND à 1 décimale sur 9 tranches
-- peut donner 99.9 ou 100.1).
--
-- 0 ligne retournée = PASS | 1+ ligne = FAIL (année incohérente)

SELECT
    year_started,
    ROUND(SUM(pct_of_year), 0) AS total_pct
FROM {{ ref('int_age_distribution') }}
GROUP BY year_started
HAVING total_pct < 99 OR total_pct > 101