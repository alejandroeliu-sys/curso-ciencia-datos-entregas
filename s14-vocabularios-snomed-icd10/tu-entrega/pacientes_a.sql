SELECT count(DISTINCT person_id) AS pacientes
FROM condition_occurrence
WHERE condition_concept_id IN (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
);

