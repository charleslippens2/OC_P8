-- mart_all_indicators.sql
-- Fichier unique consolidé pour le livrable CSV

-- Slide 8 : effectifs par année
SELECT 'effectifs_annuels' AS source_table,
       year_started::VARCHAR AS dimension,
       NULL AS detail,
       nb_students AS valeur,
       NULL AS valeur_2,
       NULL AS ecart
FROM {{ ref('int_students_by_year') }}

UNION ALL

-- Slide 9 : répartition genre par année
SELECT 'genre_evolution',
       year_started::VARCHAR,
       gender,
       nb_students,
       pct_of_year,
       NULL
FROM {{ ref('int_gender_evolution') }}

UNION ALL

-- Slide 10 : répartition âge
SELECT 'age_distribution',
       year_started::VARCHAR,
       age_group,
       nb_students,
       pct_of_year,
       NULL
FROM {{ ref('int_age_distribution') }}

UNION ALL

-- Slide 11 : répartition régions
SELECT 'region_distribution',
       year_started::VARCHAR,
       region,
       nb_students,
       pct_of_year,
       NULL
FROM {{ ref('int_region_distribution') }}

UNION ALL

-- Slide 12 : comparaison OC vs INSEE
SELECT 'comparaison_insee',
       dimension,
       detail,
       pct_oc,
       pct_insee,
       ecart_pts
FROM {{ ref('mart_comparison_insee') }}

UNION ALL

-- Slide 14 : synthèse annuelle
SELECT 'synthese_annuelle',
       year_started::VARCHAR,
       top_region || ' / ' || top_age_group,
       nb_students,
       pct_top_region,
       pct_idf
FROM {{ ref('mart_sociodemographic') }}

ORDER BY source_table, dimension