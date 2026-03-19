-- mart_livrable_csv.sql
-- Export consolidé pour le livrable CSV du projet.
-- Chaque bloc correspond à un graphique ou tableau du support de présentation.
--
-- Modèle utilitaire : aucun calcul propre, juste un assemblage UNION ALL
-- des intermédiaires et du mart_comparison_insee. Filtrable par source_table
-- pour retrouver les données exactes de chaque slide.
--
-- 5 blocs :
--   S08  → int_students_by_year (effectifs par année)
--   S09  → int_gender_evolution (parité H/F/NR par année)
--   S10  → mart_comparison_insee filtre age (distribution âge global)
--   S11  → mart_comparison_insee filtre region (répartition géo global)
--   S12_S14 → mart_comparison_insee (3 lignes clés du tableau + recommandations)
--
-- Colonnes polymorphes : valeur/valeur_2/ecart changent de signification
-- selon le bloc (effectifs, %, pct_oc/pct_insee...). Le champ source_table
-- permet de savoir comment les interpréter.
--
-- Trié par slide puis rang pour un CSV lisible de haut en bas.

-- Slide 8 : barres verticales "Effectifs par année"
-- valeur = nb_students
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

-- Slide 9 : empilé 100% "Parité Homme / Femme"
-- valeur = effectif, valeur_2 = % de l'année
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

-- Slide 10 : barres verticales "Distribution par tranche d'âge (2022-2025)"
-- valeur = pct_oc, valeur_2 = pct_insee (comparaison disponible même si
-- le graphique n'affiche que pct_oc — le pct_insee est un bonus)
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

-- Slide 11 : barres horizontales "Répartition géographique (2022-2025)"
-- Trié par pct_oc DESC pour que l'IDF apparaisse en premier
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

-- Slides 12 + 14 : tableau comparaison + synthèse recommandations
-- 3 lignes clés : % Femmes, % 25-39 ans (agrégé), % IDF
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

-- Ligne agrégée 25-39 ans : SUM des 3 tranches (25-29 + 30-34 + 35-39)
-- Car le tableau slide 12 affiche "% 25-39 ans" en une seule ligne
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