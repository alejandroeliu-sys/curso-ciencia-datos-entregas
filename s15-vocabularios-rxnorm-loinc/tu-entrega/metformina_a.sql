WITH productos_b AS (
    SELECT ca.descendant_concept_id AS drug_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id = (
        SELECT concept_id FROM concept
        WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Ingredient' AND concept_code = '6809'
    )
),
monoterapia AS (
    SELECT ca.descendant_concept_id AS drug_concept_id
    FROM concept_ancestor ca
    JOIN concept i ON i.concept_id = ca.ancestor_concept_id
    WHERE i.concept_class_id = 'Ingredient'
      AND ca.descendant_concept_id IN (SELECT drug_concept_id FROM productos_b)
    GROUP BY ca.descendant_concept_id
    HAVING count(DISTINCT i.concept_id) = 1
)
SELECT count(DISTINCT person_id) AS pacientes
FROM drug_exposure
WHERE drug_concept_id IN (SELECT drug_concept_id FROM monoterapia);
