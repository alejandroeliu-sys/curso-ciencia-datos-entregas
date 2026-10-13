-- =====================================================
-- Concept set: Hemoglobina glucosilada (HbA1c)
-- Autor: Alejandro Eliu Cedillo Rivero
-- Fecha: 2026-10-13
-- Vocabulario: LOINC 2.82
-- Base: OMOP CDM v5.4, datos Synthea (DuckDB)
-- Definición: LOINC 4548-4 (concept_id 3004410), unidad %.
--   La variante 59261-8 (IFCC) no tiene registros en esta base.
-- Limitación: RxNorm Extension no está cargado.
-- =====================================================

-- Consulta: mediciones y pacientes con HbA1c
SELECT count(*) AS mediciones,
       count(DISTINCT person_id) AS pacientes
FROM measurement
WHERE measurement_concept_id IN (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'LOINC' AND concept_code IN ('4548-4', '59261-8')
);
