-- ¿Qué variables de la tesis existen en la base Synthea?
SELECT c.concept_name, c.vocabulary_id, c.concept_id,
       COUNT(*) AS mediciones,
       COUNT(DISTINCT m.person_id) AS pacientes
FROM measurement m
JOIN concept c ON c.concept_id = m.measurement_concept_id
WHERE LOWER(c.concept_name) LIKE '%albumin%'
   OR LOWER(c.concept_name) LIKE '%creatinin%'
   OR LOWER(c.concept_name) LIKE '%cystatin%'
   OR LOWER(c.concept_name) LIKE '%interleukin%'
   OR LOWER(c.concept_name) LIKE '%exercise%'          -- MET, la actividad física
GROUP BY c.concept_name, c.vocabulary_id, c.concept_id
ORDER BY pacientes DESC;

-- Estado civil: en Synthea suele estar en la tabla observation
SELECT c.concept_name, COUNT(DISTINCT o.person_id) AS pacientes
FROM observation o
JOIN concept c ON c.concept_id = o.observation_concept_id
WHERE LOWER(c.concept_name) LIKE '%marital%'
GROUP BY c.concept_name;
