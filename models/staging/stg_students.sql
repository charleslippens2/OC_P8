-- stg_students.sql
-- Modèle staging : nettoyage et standardisation des données brutes
-- Règles appliquées :
--   1. TRIM() sur toutes colonnes texte (espaces parasites)
--   2. Genre vide/NULL → 'Non renseigné' (RGPD art. 9)
--   3. WHERE USER_ID IS NOT NULL (exclusion lignes incohérentes)
--   4. Renommage YEAR_PATH_STARTED → year_started

WITH source AS (
    SELECT * FROM {{ source('oc_raw', 'STUDENTS') }}
),
cleaned AS (
    SELECT
        USER_ID,
        PATH_CATEGORY_NAME,
        TRIM(AGE_GROUP) AS age_group,
        CASE
            WHEN TRIM(GENDER) = '' OR GENDER IS NULL
            THEN 'Non renseigné'  -- RGPD : respect du droit de non-réponse
            ELSE TRIM(GENDER)
        END AS gender,
        TRIM(REGION) AS region,
        YEAR_PATH_STARTED AS year_started
    FROM source
    WHERE USER_ID IS NOT NULL  -- Exclure lignes sans identifiant
)
SELECT * FROM cleaned
