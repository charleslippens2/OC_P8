-- stg_students.sql
-- Nettoyage de la table brute OC_P8.RAW.STUDENTS.
--
-- Règles de nettoyage :
--   1. TRIM sur toutes les colonnes texte (espaces parasites)
--   2. Genre vide ou NULL → 'Non renseigné' (RGPD art. 9, pas d'imputation)
--   3. Exclusion des lignes sans USER_ID (inutilisables pour le comptage)
--   4. Renommage YEAR_PATH_STARTED → year_started (cohérence nommage)
--
-- Choix RGPD sur le genre :
--   ~27% de valeurs vides dans le brut. Trois options possibles :
--   - Supprimer les lignes → perd 27% du dataset, biaise les analyses âge/région
--   - Imputer M ou F → fausse l'analyse de parité, contraire à l'art. 9
--   - Étiqueter 'Non renseigné' → conserve les lignes, respecte le droit de non-réponse ✓
--
-- Les 568 USER_ID présents sur plusieurs années sont des réinscriptions,
-- pas des doublons. Clé unique retenue : USER_ID + year_started
-- (vérifié par le test custom unique_student_year).
--
-- Entrée : 4647 lignes | Sortie : 4647 lignes (aucune suppression attendue)

WITH source AS (
    SELECT * FROM {{ source('oc_raw', 'STUDENTS') }}
),

cleaned AS (
    SELECT
        USER_ID,
        PATH_CATEGORY_NAME,
        TRIM(AGE_GROUP) AS age_group,

        -- Genre : recodage des vides en 'Non renseigné'
        -- Le taux de non-réponse passe de 42% (2022) à 7% (2025)
        -- → indicateur de qualité de collecte exploité en slide 9
        CASE
            WHEN TRIM(GENDER) = '' OR GENDER IS NULL
            THEN 'Non renseigné'
            ELSE TRIM(GENDER)
        END AS gender,

        TRIM(REGION) AS region,
        YEAR_PATH_STARTED AS year_started

    FROM source
    WHERE USER_ID IS NOT NULL
)

SELECT * FROM cleaned