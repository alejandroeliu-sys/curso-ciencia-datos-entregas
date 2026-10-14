-- Actividad 2: conceptos que aparecen en la recursiva pero NO en CONCEPT_ANCESTOR
WITH RECURSIVE camino AS (
    SELECT 4182210 AS concept_id, 0 AS nivel
    UNION ALL
    SELECT cr.concept_id_2, c.nivel + 1
    FROM camino c
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    WHERE cr.relationship_id = 'Is a'
      AND cr.invalid_reason IS NULL
      AND c.nivel < 20
),
diferencia AS (
    SELECT concept_id FROM camino
    EXCEPT
    SELECT ancestor_concept_id FROM concept_ancestor
    WHERE descendant_concept_id = 4182210
)
SELECT co.concept_id, co.concept_name, co.standard_concept, co.vocabulary_id
FROM diferencia d
JOIN concept co ON co.concept_id = d.concept_id;
