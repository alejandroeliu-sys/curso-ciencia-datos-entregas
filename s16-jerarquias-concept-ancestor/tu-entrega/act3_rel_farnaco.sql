-- Actividad 3.2: relaciones distintas que salen de metformina (1503297)
SELECT cr.relationship_id, r.relationship_name,
       r.is_hierarchical, r.defines_ancestry,
       count(*) AS n
FROM concept_relationship cr
JOIN relationship r ON r.relationship_id = cr.relationship_id
WHERE cr.concept_id_1 = 1503297
  AND cr.invalid_reason IS NULL
GROUP BY cr.relationship_id, r.relationship_name, r.is_hierarchical, r.defines_ancestry
ORDER BY n DESC;
