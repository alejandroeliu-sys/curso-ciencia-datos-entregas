-- =====================================================
-- Concept set: Función renal (creatinina y cistatina C)
-- Autor: Alejandro Eliu Cedillo Rivero
-- Fecha: 2026-10-13
-- Vocabulario: LOINC 2.82
-- Base: OMOP CDM v5.4, datos Synthea (DuckDB)
-- Definición: LOINC 2160-0 (creatinina sérica, concept_id 3016723)
--   y 33863-2 (cistatina C sérica, concept_id 3030366).
-- Uso: variables del proyecto final (fragilidad, HFRS, 65+).
-- =====================================================

-- Consulta: mediciones y pacientes por prueba
SELECT c.concept_code, c.concept_name,
       count(m.measurement_id) AS mediciones,
       count(DISTINCT m.person_id) AS pacientes
FROM concept c
LEFT JOIN measurement m ON m.measurement_concept_id = c.concept_id
WHERE c.vocabulary_id = 'LOINC' AND c.concept_code IN ('2160-0', '33863-2')
GROUP BY c.concept_code, c.concept_name;
