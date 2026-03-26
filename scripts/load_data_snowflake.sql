-- load_data_snowflake.sql
-- Commandes Snowflake pour créer les schémas et charger les données brutes.
-- Exécuter AVANT dbt build.

-- ============================================================
-- 1. Création de la base et des schémas
-- ============================================================

CREATE DATABASE IF NOT EXISTS OC_P8;

CREATE SCHEMA IF NOT EXISTS OC_P8.RAW;
CREATE SCHEMA IF NOT EXISTS OC_P8.RAW_INSEE;

-- ============================================================
-- 2. Chargement des données OC (STUDENTS)
-- ============================================================

-- Méthode : Snowsight → Data → Load Data → sélectionner le CSV OC
-- Résultat : OC_P8.RAW.STUDENTS (4647 lignes, 6 colonnes)

-- Vérification :
SELECT COUNT(*) AS nb_lignes FROM OC_P8.RAW.STUDENTS;
-- Attendu : 4647

-- ============================================================
-- 3. Chargement des données INSEE (POPULATION_REGION)
-- ============================================================

-- Fichier source : insee_population_region.csv
-- Produit par : scripts/convert_insee_xlsx_to_csv.py
-- Méthode : Snowsight → Data → Load Data → sélectionner le CSV

-- Vérification :
SELECT COUNT(*) AS nb_lignes FROM OC_P8.RAW_INSEE.POPULATION_REGION;
-- Attendu : ~4560

SELECT DISTINCT REGION FROM OC_P8.RAW_INSEE.POPULATION_REGION ORDER BY REGION;
SELECT DISTINCT ANNEE FROM OC_P8.RAW_INSEE.POPULATION_REGION ORDER BY ANNEE;