-- Actividad 1: factibilidad. Seguimiento (cuartiles) y número de desenlaces
WITH coh AS (
  SELECT subject_id AS person_id, cohort_start_date, cohort_end_date
  FROM results.cohort
  WHERE cohort_definition_id =1701
),
eventos AS (
  SELECT c.person_id,
    EXISTS (SELECT 1 FROM visit_occurrence v
            WHERE v.person_id = c.person_id
              AND v.visit_concept_id = 9201
              AND v.visit_start_date >  c.cohort_start_date
              AND v.visit_start_date <= c.cohort_end_date) AS reingreso,
    EXISTS (SELECT 1 FROM visit_occurrence v
            WHERE v.person_id = c.person_id
              AND v.visit_concept_id = 9203
              AND v.visit_start_date >  c.cohort_start_date
              AND v.visit_start_date <= c.cohort_end_date) AS urgencias
  FROM coh c
)
SELECT
  (SELECT COUNT(*) FROM coh) AS pacientes,
  (SELECT QUANTILE_CONT(cohort_end_date - cohort_start_date, 0.25) FROM coh) AS seg_p25,
  (SELECT MEDIAN(cohort_end_date - cohort_start_date) FROM coh)              AS seg_mediana,
  (SELECT QUANTILE_CONT(cohort_end_date - cohort_start_date, 0.75) FROM coh) AS seg_p75,
  SUM(CASE WHEN reingreso THEN 1 ELSE 0 END) AS con_reingreso,
  SUM(CASE WHEN urgencias THEN 1 ELSE 0 END) AS con_urgencias,
  SUM(CASE WHEN reingreso OR urgencias THEN 1 ELSE 0 END) AS con_desenlace_compuesto
FROM eventos;
