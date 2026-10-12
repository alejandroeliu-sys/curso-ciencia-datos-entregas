SELECT count(DISTINCT person_id) AS pacientes
FROM condition_occurrence
WHERE condition_concept_id IN(
    SELECT ca.descendant_concept_id AS concept_id
FROM concept_ancestor ca
WHERE ca.ancestor_concept_id = (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
)
EXCEPT
SELECT ca.descendant_concept_id
FROM concept_ancestor ca
WHERE ca.ancestor_concept_id IN(4182539,4019705,4047752,374341,37204554,37162253,37166530,42538609,37166361,37166338,(SELECT concept_id FROM concept WHERE vocabulary_id = 'SNOMED' AND concept_code = '230265002'))
);

