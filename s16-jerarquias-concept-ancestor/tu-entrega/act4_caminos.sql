-- Actividad 4.2: los caminos completos de demencia (4182210) a 4046090
WITH RECURSIVE bajada AS (
    SELECT 4182210 AS concept_id, 0 AS nivel,
           CAST(4182210 AS VARCHAR) AS ruta
    UNION ALL
    SELECT cr.concept_id_1, b.nivel + 1,
           b.ruta || ' > ' || CAST(cr.concept_id_1 AS VARCHAR)
    FROM bajada b
    JOIN concept_relationship cr ON cr.concept_id_2 = b.concept_id
    WHERE cr.relationship_id = 'Is a'
      AND cr.invalid_reason IS NULL
      AND b.nivel < 6
)
SELECT nivel, ruta
FROM bajada
WHERE concept_id = 4046090;
