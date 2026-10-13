-- Actividad 7.1: unidades usadas en las mediciones de HbA1c (4548-4)
SELECT u.concept_code AS unidad,
       count(*) AS mediciones,
       min(m.value_as_number) AS minimo,
       max(m.value_as_number) AS maximo,
       avg(m.value_as_number) AS promedio
FROM measurement m
LEFT JOIN concept u ON u.concept_id = m.unit_concept_id
WHERE m.measurement_concept_id = 3004410
GROUP BY u.concept_code
ORDER BY mediciones DESC;
