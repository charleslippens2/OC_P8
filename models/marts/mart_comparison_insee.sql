-- mart_comparison_insee.sql
-- Modèle mart : comparaison du profil OC avec la population française (INSEE)
--
-- RÔLE : croiser les données OC avec les données INSEE pour mesurer
--        les écarts entre le profil des étudiants Data et la population française.
--        C'est la CONTEXTUALISATION qui transforme un chiffre en enseignement actionnable.
--        Sans ce mart : "31% de femmes". Avec : "31% vs 51% = déficit de 20 points".
--
-- INDICATEURS PRODUITS :
--   8. Comparaison OC vs INSEE par RÉGION (surreprésentation/sous-représentation)
--   9. Comparaison OC vs INSEE par GENRE (écart de parité)
--   10. Comparaison OC vs INSEE par ÂGE (profil reconversion vs population active)
--
-- RÉSULTAT : ~25 lignes avec une structure uniforme :
--   | dimension (region/genre/age) | detail | pct_oc | pct_insee | ecart_pts | ratio |
--   → 13 lignes région + 1 ligne genre + 9 lignes âge + Corse (NULL côté OC)
--
-- ALIMENTE : slide 12 (tableau comparaison, la slide la plus impactante)
--
-- CHOIX TECHNIQUES :
--   - Lit stg_students et stg_insee_population (pas les intermédiaires)
--     car les intermédiaires sont découpés par année, alors que la comparaison
--     INSEE est globale (toutes années OC vs population 2023).
--   - INSEE filtré sur annee = 2023 : données définitives (2024-2025 = estimations).
--   - UNION ALL pour regrouper les 3 comparaisons dans une seule table
--     avec une colonne 'dimension' → plus propre que 3 tables séparées.
--   - FULL OUTER JOIN pour région et âge : si une région/tranche existe
--     dans l'INSEE mais pas dans OC (ex: Corse), elle apparaît avec pct_oc = NULL.
--
-- MATÉRIALISATION : table (résultat final pour la direction).


-- =====================================================================
-- COMPARAISON PAR RÉGION (indicateur 8)
-- Question : les étudiants OC sont-ils répartis comme la population ?
-- Enseignement attendu : IDF surreprésentée ×2,5, provinces sous-représentées
-- =====================================================================

WITH oc_regions AS (
    -- Pourcentage d'étudiants OC par région (toutes années confondues)
    -- SUM(COUNT(*)) OVER () = total global (4647) sans GROUP BY supplémentaire
    -- On prend toutes les années car on compare le profil GLOBAL d'OC
    SELECT
        region,
        COUNT(*) AS nb_oc,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_oc
    FROM {{ ref('stg_students') }}
    GROUP BY region
),

insee_regions AS (
    -- Pourcentage de la population française par région (INSEE 2023)
    -- Filtré sur sexe = 'Ensemble' pour avoir le total (pas H ou F séparément)
    -- Filtré sur annee = 2023 : données définitives (pas estimations)
    -- SUM(population) : agrège toutes les tranches d'âge par région
    SELECT
        region,
        SUM(population) AS pop_insee,
        ROUND(SUM(population) * 100.0 / SUM(SUM(population)) OVER (), 1) AS pct_insee
    FROM {{ ref('stg_insee_population') }}
    WHERE sexe = 'Ensemble' AND annee = 2023
    GROUP BY region
),

comp_region AS (
    -- Croisement OC × INSEE par région
    -- COALESCE : si une région est dans l'INSEE mais pas OC (Corse),
    --   on garde le nom INSEE. pct_oc sera NULL.
    -- FULL OUTER JOIN : garde toutes les régions des deux côtés
    -- ecart_pts : différence en points de pourcentage (+ = surreprésenté chez OC)
    -- ratio : facteur multiplicatif (2.5 = OC a 2,5× plus que son poids démographique)
    -- NULLIF : évite la division par zéro si pct_insee = 0 (improbable mais sécuritaire)
    SELECT
        COALESCE(o.region, i.region) AS region,
        o.nb_oc,
        o.pct_oc,
        i.pop_insee,
        i.pct_insee,
        ROUND(o.pct_oc - i.pct_insee, 1) AS ecart_pts,
        ROUND(o.pct_oc / NULLIF(i.pct_insee, 0), 2) AS ratio
    FROM oc_regions o
    FULL OUTER JOIN insee_regions i ON o.region = i.region
),


-- =====================================================================
-- COMPARAISON PAR GENRE (indicateur 9)
-- Question : la parité chez OC est-elle comparable à la population ?
-- Enseignement attendu : ~31% femmes OC vs ~51% INSEE = déficit 20 pts
-- =====================================================================

oc_gender AS (
    -- Pourcentage de femmes PARMI LES RÉPONDANTS chez OC
    -- Dénominateur = M + F (exclut 'Non renseigné')
    -- POURQUOI exclure NR : inclure les NR diluerait le taux (23% au lieu de 31%)
    -- NULLIF : si aucun répondant au genre (division par zéro)
    SELECT
        ROUND(
            COUNT(CASE WHEN gender = 'F' THEN 1 END) * 100.0
            / NULLIF(COUNT(CASE WHEN gender IN ('M', 'F') THEN 1 END), 0),
        1) AS pct_f_oc
    FROM {{ ref('stg_students') }}
),

insee_gender AS (
    -- Pourcentage de femmes dans la population française (INSEE 2023)
    -- Numérateur : population où sexe = 'F'
    -- Dénominateur : population où sexe = 'Ensemble' (= total H+F)
    -- Note : 'Ensemble' dans l'INSEE = Hommes + Femmes (pas un 3ème genre)
    SELECT
        ROUND(
            SUM(CASE WHEN sexe = 'F' THEN population END) * 100.0
            / SUM(CASE WHEN sexe = 'Ensemble' THEN population END),
        1) AS pct_f_insee
    FROM {{ ref('stg_insee_population') }}
    WHERE annee = 2023
),

comp_gender AS (
    -- Croisement : écart de parité OC vs population
    -- Résultat attendu : ~31% - ~51% = -20 pts (déficit de parité)
    -- Un seul résultat (1 ligne), pas besoin de JOIN par clé
    -- La virgule entre les 2 tables = CROSS JOIN implicite (1×1 = 1 ligne)
    SELECT
        pct_f_oc,
        pct_f_insee,
        ROUND(pct_f_oc - pct_f_insee, 1) AS ecart_pts
    FROM oc_gender, insee_gender
),


-- =====================================================================
-- COMPARAISON PAR ÂGE (indicateur 10)
-- Question : le profil d'âge OC est-il comparable à la population active ?
-- Enseignement attendu : 25-39 ans surreprésentés ×2,7 (profil reconversion)
-- =====================================================================

oc_age AS (
    -- Pourcentage d'étudiants OC par tranche d'âge (toutes années)
    -- Même logique que oc_regions : SUM(COUNT(*)) OVER pour le total global
    SELECT
        age_group,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_oc
    FROM {{ ref('stg_students') }}
    GROUP BY age_group
),

insee_age AS (
    -- Pourcentage de la population française par tranche d'âge (INSEE 2023)
    -- Filtré sexe = 'Ensemble' et annee = 2023
    -- Note : le staging INSEE a déjà exclu les < 20 ans et agrégé les 60+
    -- donc les tranches correspondent à celles d'OC (20-24 à 60+)
    SELECT
        age_group,
        ROUND(SUM(population) * 100.0 / SUM(SUM(population)) OVER (), 1) AS pct_insee
    FROM {{ ref('stg_insee_population') }}
    WHERE sexe = 'Ensemble' AND annee = 2023
    GROUP BY age_group
),

comp_age AS (
    -- Croisement OC × INSEE par tranche d'âge
    -- FULL OUTER JOIN : si une tranche existe d'un côté mais pas l'autre
    -- ecart_pts positif = surreprésenté chez OC (ex: 25-29 ans = +8 pts)
    -- ecart_pts négatif = sous-représenté chez OC (ex: 50+ ans = -10 pts)
    SELECT
        COALESCE(o.age_group, i.age_group) AS age_group,
        o.pct_oc,
        i.pct_insee,
        ROUND(o.pct_oc - i.pct_insee, 1) AS ecart_pts
    FROM oc_age o
    FULL OUTER JOIN insee_age i ON o.age_group = i.age_group
)


-- =====================================================================
-- ASSEMBLAGE : UNION ALL des 3 comparaisons
-- Toutes dans une seule table avec une colonne 'dimension' pour les distinguer
-- POURQUOI UNION ALL : plus propre que 3 tables séparées.
--   Un seul SELECT dans le mart → un seul tableau dans la slide 12.
-- ORDER BY dimension, ecart_pts DESC : les plus gros écarts en premier
-- =====================================================================

-- Dimension RÉGION : 13-14 lignes (13 régions OC + Corse si dans INSEE)
SELECT
    'region' AS dimension,   -- Pour filtrer : WHERE dimension = 'region'
    region AS detail,        -- Nom de la région
    pct_oc,                  -- % d'étudiants OC dans cette région
    pct_insee,               -- % de la population française dans cette région
    ecart_pts,               -- Différence en points (+ = surreprésenté OC)
    ratio                    -- Facteur multiplicatif (2.5 = OC a 2,5× plus)
FROM comp_region

UNION ALL

-- Dimension GENRE : 1 seule ligne (% femmes OC vs INSEE)
SELECT
    'genre' AS dimension,
    'Femmes' AS detail,      -- On compare le % de femmes
    pct_f_oc AS pct_oc,      -- ~31% (parmi répondants OC)
    pct_f_insee AS pct_insee, -- ~51% (population française)
    ecart_pts,               -- ~-20 pts (déficit de parité)
    NULL AS ratio            -- Pas de ratio pour le genre (une seule ligne)
FROM comp_gender

UNION ALL

-- Dimension ÂGE : 9 lignes (une par tranche d'âge)
SELECT
    'age' AS dimension,
    age_group AS detail,     -- Nom de la tranche (20-24 ans, 25-29 ans, etc.)
    pct_oc,                  -- % d'étudiants OC dans cette tranche
    pct_insee,               -- % de la population dans cette tranche
    ecart_pts,               -- Différence (+ = surreprésenté, - = sous-représenté)
    NULL AS ratio            -- Pas de ratio par tranche (déjà dans l'écart)
FROM comp_age

ORDER BY dimension, ecart_pts DESC