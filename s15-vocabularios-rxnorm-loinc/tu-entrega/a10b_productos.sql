WITH ingredientes AS (
    SELECT ca.descendant_concept_id AS ingrediente_id
    FROM concept atc
    JOIN concept_ancestor ca ON ca.ancestor_concept_id = atc.concept_id
    JOIN concept i ON i.concept_id = ca.descendant_concept_id
    WHERE atc.vocabulary_id = 'ATC' AND atc.concept_code = 'A10B'
      AND i.concept_class_id = 'Ingredient' AND i.standard_concept = 'S'
),
productos AS (
    SELECT DISTINCT ca.descendant_concept_id AS drug_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id IN (SELECT ingrediente_id FROM ingredientes)
)
SELECT count(DISTINCT de.drug_concept_id) AS productos,
       count(DISTINCT de.person_id) AS pacientes
FROM drug_exposure de
WHERE de.drug_concept_id IN (SELECT drug_concept_id FROM productos);
