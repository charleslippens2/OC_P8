-- mart_livrable_csv.sql
-- Fichier unique consolidé pour le livrable CSV
-- Chaque bloc correspond exactement à un graphique ou tableau du PPT

-- Slide 8 : graphique barres "Effectifs par année"
SELECT 8 AS slide,
       'S08_effectifs_par_annee' AS source_table,
       year_started::VARCHAR AS dimension,
       NULL AS detail,
       nb_students AS valeur,
       NULL AS valeur_2,
       NULL AS ecart,
       ROW_NUMBER() OVER (ORDER BY year_started) AS rang
FROM {{ ref('int_students_by_year') }}

UNION ALL

-- Slide 9 : graphique empilé "Parité Homme / Femme"
SELECT 9,
       'S09_parite_homme_femme',
       year_started::VARCHAR,
       gender,
       nb_students,
       pct_of_year,
       NULL,
       ROW_NUMBER() OVER (ORDER BY year_started, gender)
FROM {{ ref('int_gender_evolution') }}

UNION ALL

-- Slide 10 : graphique barres "Distribution par tranche d'âge (2022-2025)"
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

-- Slide 11 : graphique barres horizontales "Répartition géographique (2022-2025)"
SELECT 11,
       'S11_repartition_geographique',
       'global',
       detail,
       pct_oc,
       pct_insee,
       ecart_pts,
       ROW_NUMBER() OVER (ORDER BY pct_oc DESC NULLS LAST)
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'region'

UNION ALL

-- Slides 12-14 : tableau "Comparaison OC vs INSEE" + "Synthèse et recommandations"
SELECT 12,
       'S12_S14_comparaison_insee_synthese',
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

SELECT 12,
       'S12_S14_comparaison_insee_synthese',
       'age',
       '25-39 ans',
       SUM(pct_oc),
       SUM(pct_insee),
       ROUND(SUM(pct_oc) - SUM(pct_insee), 1),
       3
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'age'
  AND detail IN ('25-29 ans', '30-34 ans', '35-39 ans')

ORDER BY slide, rang