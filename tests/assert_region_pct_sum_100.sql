-- tests/assert_region_pct_sum_100.sql
-- Vérifie que les % par région totalisent ~100% pour chaque année.
-- Même logique que assert_percentages_sum_100 mais sur int_region_distribution.
-- Les deux modèles calculent des % indépendamment — on vérifie les deux.
--
-- Marge 99-101 pour les arrondis. Détecte une région manquante ou en doublon.
--
-- 0 ligne retournée = PASS | 1+ ligne = FAIL

SELECT
    year_started,
    ROUND(SUM(pct_of_year), 0) AS total_pct
FROM {{ ref('int_region_distribution') }}
GROUP BY year_started
HAVING total_pct < 99 OR total_pct > 101