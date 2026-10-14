-- Actividad 4.1: descendientes de demencia con más de un camino (poli-jerarquía)
SELECT ca.descendant_concept_id, co.concept_name,
       ca.min_levels_of_separation AS nivel_min,
       ca.max_levels_of_separation AS nivel_max
FROM concept_ancestor ca
JOIN concept co ON co.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = 4182210
  AND ca.min_levels_of_separation <> ca.max_levels_of_separation
ORDER BY nivel_max DESC
LIMIT 15;
