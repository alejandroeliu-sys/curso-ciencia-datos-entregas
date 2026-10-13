WITH productos_b AS (
    SELECT ca.descendant_concept_id AS drug_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id = (
        SELECT concept_id FROM concept
        WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Ingredient' AND concept_code = '6809'
    )
),
con_isglt2 AS (
    SELECT ca.descendant_concept_id AS drug_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id = (
        SELECT concept_id FROM concept
        WHERE vocabulary_id = 'ATC' AND concept_code = 'A10BK'
    )
)
SELECT count(DISTINCT person_id) AS pacientes
FROM drug_exposure
WHERE drug_concept_id IN (SELECT drug_concept_id FROM productos_b)
  AND drug_concept_id NOT IN (SELECT drug_concept_id FROM con_isglt2);
