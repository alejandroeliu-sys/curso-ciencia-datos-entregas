-- Actividad 7: conceptos retirados dentro del concept set de demencia
SELECT c.invalid_reason, count(*) AS conceptos
FROM concept_ancestor ca
JOIN concept c ON c.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = 4182210
GROUP BY c.invalid_reason
ORDER BY conceptos DESC;
