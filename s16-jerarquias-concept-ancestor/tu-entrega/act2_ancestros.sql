-- Actividad 2: ancestros de demencia (4182210) con CONCEPT_ANCESTOR
SELECT ca.ancestor_concept_id AS concept_id, co.concept_name,
       ca.min_levels_of_separation AS nivel_min,
       ca.max_levels_of_separation AS nivel_max
FROM concept_ancestor ca
JOIN concept co ON co.concept_id = ca.ancestor_concept_id
WHERE ca.descendant_concept_id = 4182210
ORDER BY nivel_min, nivel_max;
