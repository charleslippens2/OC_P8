-- mart_livrable_csv.sql
-- Fichier unique consolidé pour le livrable CSV
-- Chaque bloc correspond à une slide du PPT

-- Slide 8 : effectifs par année (source: int_students_by_year)
SELECT 'effectifs_annuels' AS source_table,
       year_started::VARCHAR AS dimension,
       NULL AS detail,
       nb_students AS valeur,
       NULL AS valeur_2,
       NULL AS ecart
FROM {{ ref('int_students_by_year') }}

UNION ALL

-- Slide 9 : répartition genre par année (source: int_gender_evolution)
SELECT 'genre_evolution',
       year_started::VARCHAR,
       gender,
       nb_students,
       pct_of_year,
       NULL
FROM {{ ref('int_gender_evolution') }}

UNION ALL

-- Slide 10 : répartition âge global (source: mart_comparison_insee)
SELECT 'age_distribution',
       'global',
       detail,
       pct_oc,
       pct_insee,
       ecart_pts
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'age'

UNION ALL

-- Slide 11 : répartition régions global (source: mart_comparison_insee)
SELECT 'region_distribution',
       'global',
       detail,
       pct_oc,
       pct_insee,
       ecart_pts
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'region'

UNION ALL

-- Slides 12 et 14 : tableau comparaison + synthèse recommandations (3 lignes clés)
SELECT 'comparaison_synthese' AS source_table,
       dimension,
       detail,
       pct_oc,
       pct_insee,
       ecart_pts
FROM {{ ref('mart_comparison_insee') }}
WHERE (dimension = 'genre' AND detail = 'Femmes')
   OR (dimension = 'region' AND detail = 'Île-de-France')

UNION ALL

-- Slides 12 et 14 : ligne 25-39 ans agrégée
SELECT 'comparaison_synthese',
       'age',
       '25-39 ans',
       SUM(pct_oc),
       SUM(pct_insee),
       ROUND(SUM(pct_oc) - SUM(pct_insee), 1)
FROM {{ ref('mart_comparison_insee') }}
WHERE dimension = 'age'
  AND detail IN ('25-29 ans', '30-34 ans', '35-39 ans')