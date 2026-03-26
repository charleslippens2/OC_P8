-- requetes_verification_snowflake.sql
-- Requêtes de vérification du pipeline dbt + exports CSV.
-- Exécuter APRÈS dbt build.

-- ============================================================
-- VÉRIFICATIONS GLOBALES
-- ============================================================

SELECT COUNT(*) AS total FROM OC_P8.DBT_CLIPPENS.STG_STUDENTS;
-- Attendu : 4647

SELECT COUNT(DISTINCT USER_ID) AS nb_distincts FROM OC_P8.DBT_CLIPPENS.STG_STUDENTS;
-- Attendu : ~4010

SELECT COUNT(*) AS nb_reinscrits
FROM (
    SELECT USER_ID FROM OC_P8.DBT_CLIPPENS.STG_STUDENTS
    GROUP BY USER_ID HAVING COUNT(*) > 1
);
-- Attendu : 568

SELECT gender, COUNT(*) AS nb
FROM OC_P8.DBT_CLIPPENS.STG_STUDENTS
GROUP BY gender ORDER BY nb DESC;
-- Attendu : M, F, Non renseigné (pas de NULL)

-- ============================================================
-- SLIDE 8 — Effectifs par année
-- ============================================================

SELECT year_started, nb_students, nb_students_distincts
FROM OC_P8.DBT_CLIPPENS.INT_STUDENTS_BY_YEAR
ORDER BY year_started;
-- Attendu : 2022:1696, 2023:1150, 2024:850, 2025:951

-- ============================================================
-- SLIDE 9 — Parité H/F
-- ============================================================

SELECT year_started, gender, pct_of_year
FROM OC_P8.DBT_CLIPPENS.INT_GENDER_EVOLUTION
ORDER BY year_started, gender;

SELECT year_started, pct_among_declared
FROM OC_P8.DBT_CLIPPENS.INT_GENDER_EVOLUTION
WHERE gender = 'F'
ORDER BY year_started;
-- Attendu : ~31% stable sur 4 ans

-- ============================================================
-- SLIDE 10 — Distribution âge (global)
-- ============================================================

SELECT detail AS age_group, pct_oc, pct_insee, ecart_pts
FROM OC_P8.DBT_CLIPPENS.MART_COMPARISON_INSEE
WHERE dimension = 'age'
ORDER BY pct_oc DESC;

-- ============================================================
-- SLIDE 11 — Évolution âge top 5 par année
-- ============================================================

SELECT year_started, age_group, pct_of_year
FROM OC_P8.DBT_CLIPPENS.INT_AGE_DISTRIBUTION
WHERE rang <= 5
ORDER BY year_started, pct_of_year DESC;

-- ============================================================
-- SLIDE 12 — Répartition géographique (global)
-- ============================================================

SELECT detail AS region, pct_oc, pct_insee, ecart_pts, ratio
FROM OC_P8.DBT_CLIPPENS.MART_COMPARISON_INSEE
WHERE dimension = 'region'
ORDER BY pct_oc DESC NULLS LAST;

-- ============================================================
-- SLIDE 13 — Évolution % IDF par année
-- ============================================================

SELECT year_started, pct_of_year AS pct_idf
FROM OC_P8.DBT_CLIPPENS.INT_REGION_DISTRIBUTION
WHERE region = 'Île-de-France'
ORDER BY year_started;
-- Attendu : 44.9, 54.1, 40.6, 41.1

-- ============================================================
-- SLIDES 14 + 16 — Comparaison OC vs INSEE
-- ============================================================

SELECT dimension, detail, pct_oc, pct_insee, ecart_pts
FROM OC_P8.DBT_CLIPPENS.MART_COMPARISON_INSEE
WHERE (dimension = 'genre' AND detail = 'Femmes')
   OR (dimension = 'region' AND detail = 'Île-de-France')
UNION ALL
SELECT 'age', '25-39 ans',
       ROUND(SUM(pct_oc), 1),
       ROUND(SUM(pct_insee), 1),
       ROUND(SUM(pct_oc) - SUM(pct_insee), 1)
FROM OC_P8.DBT_CLIPPENS.MART_COMPARISON_INSEE
WHERE dimension = 'age'
  AND detail IN ('25-29 ans', '30-34 ans', '35-39 ans');
-- Attendu : Femmes 31.1/52.4/-21.3, Age 63.7/23.3/+40.4, IDF 45.6/17.4/+28.2

-- ============================================================
-- VÉRIFICATION MART LIVRABLE CSV
-- ============================================================

SELECT slide, source_table, COUNT(*) AS nb_lignes
FROM OC_P8.DBT_CLIPPENS.MART_LIVRABLE_CSV
GROUP BY slide, source_table
ORDER BY slide;
-- Attendu : S08=4, S09=12, S10=9, S11=20, S12=14, S13=4, S14=3

-- ============================================================
-- EXPORTS CSV (télécharger via Download)
-- ============================================================

-- Export staging (données nettoyées individuelles)
SELECT * FROM OC_P8.DBT_CLIPPENS.STG_STUDENTS
ORDER BY year_started, region, age_group, gender;
-- 4647 lignes → Download CSV

-- Export mart (indicateurs agrégés par slide)
SELECT * FROM OC_P8.DBT_CLIPPENS.MART_LIVRABLE_CSV
ORDER BY slide, rang;
-- ~66 lignes → Download CSV