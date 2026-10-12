SELECT c.concept_id, c.concept_name
FROM concept_ancestor ca
JOIN concept c ON c.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
)
ORDER BY c.concept_name;
