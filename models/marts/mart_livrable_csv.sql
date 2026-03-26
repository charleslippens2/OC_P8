-- mart_livrable_csv.sql
-- Export consolidé pour le livrable CSV du projet.
-- 7 blocs correspondant aux 7 slides de résultats (17 slides au total).
--
-- Corrections appliquées :
--   - CAST AS INT sur les effectifs (pas de .0 dans le CSV)
--   - PARTITION BY year_started pour le rang S09 (1-3 par année, pas 1-12 global)
--   - ROUND(x, 1) partout pour éviter les sommes à 100.1%
--
-- Trié par slide puis rang pour un CSV lisible de haut en bas.

-- Slide 8 : barres verticales "Effectifs par année"
SELECT 8 AS slide,
       'S08_effectifs_par_annee' AS source_table,
       year_started::VARCHAR AS dimension,
       NULL AS detail,
       CAST(nb_students AS INT) AS valeur,
       NULL AS valeur_2,
       NULL AS ecart,
       ROW_NUMBER() OVER (ORDER BY year_started) AS rang
FROM {{ ref('int_students_by_year') }}

UNION ALL

-- Slide 9 : empilé 100% "Parité Homme / Femme"
SELECT 9,
       'S09_parite_homme_femme',
       year_started::VARCHAR,
       gender,
       CAST(nb_students AS INT),
       pct_of_year,
       NULL,
       ROW_NUMBER() OVER (PARTITION BY year_started ORDER BY gender)
FROM {{ ref('int_gender_evolution') }}

UNION ALL

-- Slide 10 : barres verticales "Distribution par tranche d'âge (global)"
SELECT 10,
       'S10_distribution_age',
       'global',
       detail,
       pct_oc,
       pct_insee,
       ecart_pts,
       ROW_NUMBER() OVER (ORDER BY detail)
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'age'

UNION ALL

-- Slide 11 : barres groupées "Évolution top 5 tranches d'âge"
SELECT 11,
       'S11_evolution_age_top5',
       year_started::VARCHAR,
       age_group,
       pct_of_year,
       NULL,
       NULL,
       ROW_NUMBER() OVER (ORDER BY year_started, pct_of_year DESC)
FROM {{ ref('int_age_distribution') }}
WHERE rang <= 5

UNION ALL

-- Slide 12 : barres horizontales "Répartition géographique (global)"
SELECT 12,
       'S12_repartition_geographique',
       'global',
       detail,
       pct_oc,
       pct_insee,
       ecart_pts,
       ROW_NUMBER() OVER (ORDER BY pct_oc DESC NULLS LAST)
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'region'

UNION ALL

-- Slide 13 : courbe "Évolution % IDF par année"
SELECT 13,
       'S13_evolution_pct_idf',
       year_started::VARCHAR,
       'Île-de-France',
       pct_of_year,
       NULL,
       NULL,
       ROW_NUMBER() OVER (ORDER BY year_started)
FROM {{ ref('int_region_distribution') }}
WHERE region = 'Île-de-France'

UNION ALL

-- Slides 14 + 16 : tableau comparaison + synthèse recommandations
SELECT 14,
       'S14_S16_comparaison_insee_synthese',
       dimension,
       detail,
       pct_oc,
       pct_insee,
       ecart_pts,
       ROW_NUMBER() OVER (ORDER BY dimension)
FROM {{ ref('mart_comparison_insee') }}
WHERE (dimension = 'genre' AND detail = 'Femmes')
   OR (dimension = 'region' AND detail = 'Île-de-France')

UNION ALL

-- Ligne agrégée 25-39 ans
SELECT 14,
       'S14_S16_comparaison_insee_synthese',
       'age',
       '25-39 ans',
       ROUND(SUM(pct_oc), 1),
       ROUND(SUM(pct_insee), 1),
       ROUND(SUM(pct_oc) - SUM(pct_insee), 1),
       3
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'age'
  AND detail IN ('25-29 ans', '30-34 ans', '35-39 ans')

ORDER BY slide, rang