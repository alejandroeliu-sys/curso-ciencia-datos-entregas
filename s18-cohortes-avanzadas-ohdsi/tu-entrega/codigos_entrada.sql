-- Actividad 6: diagnósticos registrados en la hospitalización índice
WITH visita_indice AS (
  SELECT c.subject_id, v.visit_occurrence_id
  FROM results.cohort c
  JOIN visit_occurrence v
    ON v.person_id = c.subject_id
   AND v.visit_concept_id = 9201
   AND v.visit_end_date = c.cohort_start_date
  WHERE c.cohort_definition_id = 1701
)
SELECT co.condition_concept_id,
       ct.concept_name,
       COUNT(DISTINCT vi.subject_id) AS pacientes,
       ROUND(100.0 * COUNT(DISTINCT vi.subject_id) / 196, 1) AS porcentaje
FROM visita_indice vi
JOIN condition_occurrence co ON co.visit_occurrence_id = vi.visit_occurrence_id
JOIN concept ct ON ct.concept_id = co.condition_concept_id
GROUP BY co.condition_concept_id, ct.concept_name
ORDER BY pacientes DESC
LIMIT 15;
