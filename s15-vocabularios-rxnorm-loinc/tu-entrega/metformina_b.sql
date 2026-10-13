SELECT count(DISTINCT person_id) AS pacientes
FROM drug_exposure
WHERE drug_concept_id IN (
    SELECT ca.descendant_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id = (
        SELECT concept_id FROM concept
        WHERE vocabulary_id = 'RxNorm'
          AND concept_class_id = 'Ingredient'
          AND concept_code = '6809'
    )
);
