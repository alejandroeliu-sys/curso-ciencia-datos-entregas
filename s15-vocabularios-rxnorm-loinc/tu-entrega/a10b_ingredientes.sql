SELECT i.concept_id, i.concept_name
FROM concept atc
JOIN concept_ancestor ca ON ca.ancestor_concept_id = atc.concept_id
JOIN concept i ON i.concept_id = ca.descendant_concept_id
WHERE atc.vocabulary_id = 'ATC'
  AND atc.concept_code = 'A10B'
  AND i.concept_class_id = 'Ingredient'
  AND i.standard_concept = 'S'
ORDER BY i.concept_name;
