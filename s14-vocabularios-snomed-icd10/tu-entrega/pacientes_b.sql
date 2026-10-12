SELECT count(DISTINCT person_id) AS pacientes
FROM condition_occurrence
WHERE condition_concept_id IN (
    SELECT ca.descendant_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id = (
        SELECT concept_id FROM concept
        WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
    )
);
