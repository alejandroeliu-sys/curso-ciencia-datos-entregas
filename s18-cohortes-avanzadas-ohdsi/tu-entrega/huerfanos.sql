-- Actividad 7: tipos de visita en la base (candidatos a conceptos huérfanos)
SELECT v.visit_concept_id,
       c.concept_name,
       COUNT(*) AS visitas,
       COUNT(DISTINCT v.person_id) AS pacientes
FROM visit_occurrence v
LEFT JOIN concept c ON c.concept_id = v.visit_concept_id
GROUP BY v.visit_concept_id, c.concept_name
ORDER BY visitas DESC;


-- Actividad 7b: duración de las visitas sin mapear (0) comparada con 9201 y 9202
SELECT visit_concept_id,
       COUNT(*) AS visitas,
       SUM(CASE WHEN visit_end_date > visit_start_date THEN 1 ELSE 0 END) AS de_1_dia_o_mas,
       ROUND(100.0 * SUM(CASE WHEN visit_end_date > visit_start_date THEN 1 ELSE 0 END) / COUNT(*), 1) AS porcentaje,
       MEDIAN(visit_end_date - visit_start_date) AS mediana_dias
FROM visit_occurrence
WHERE visit_concept_id IN (0, 9201, 9202)
GROUP BY visit_concept_id;
