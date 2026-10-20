-- ============================================================
-- LABORATORIO 17 – Cohorte 1701: primer egreso hospitalario a los 65+
-- Base: OMOP CDM v5.4 (Synthea) en DuckDB
-- ============================================================

-- PASO 2. EVENTO INICIAL
-- Primer egreso hospitalario (visit_concept_id 9201) a los 65 años o más.
-- Fecha índice = fecha de egreso. Una fila por persona.
WITH egresos AS (
  SELECT v.person_id,
         v.visit_start_date AS fecha_ingreso,
         v.visit_end_date   AS fecha_indice,
         ROW_NUMBER() OVER (PARTITION BY v.person_id
                            ORDER BY v.visit_end_date) AS orden
  FROM visit_occurrence v
  JOIN person p ON p.person_id = v.person_id
  WHERE v.visit_concept_id = 9201
    AND YEAR(v.visit_end_date) - p.year_of_birth >= 65
),
evento_inicial AS (
  SELECT person_id, fecha_ingreso, fecha_indice
  FROM egresos
  WHERE orden = 1
)
,
-- PASO 3. OBSERVACIÓN PREVIA
-- El periodo debe CONTENER la fecha índice y extenderse 730 días hacia atrás
-- (el mismo periodo, continuo; no basta la resta de fechas extremas).
observacion_previa AS (
  SELECT e.*, op.observation_period_end_date AS fin_observacion
  FROM evento_inicial e
  JOIN observation_period op ON op.person_id = e.person_id
  WHERE e.fecha_indice BETWEEN op.observation_period_start_date
                           AND op.observation_period_end_date
    AND op.observation_period_start_date <= e.fecha_indice - INTERVAL 730 DAY
)
,
-- PASO 4. LAVADO
-- Ninguna OTRA hospitalización que termine en los 30 días previos al ingreso índice
-- (para que el egreso índice no sea un reingreso). Se reporta aparte de la observación previa.
lavado AS (
  SELECT o.*
  FROM observacion_previa o
  WHERE NOT EXISTS (
    SELECT 1 FROM visit_occurrence v
    WHERE v.person_id = o.person_id
      AND v.visit_concept_id = 9201
      AND v.visit_end_date >= o.fecha_ingreso - INTERVAL 30 DAY
      AND v.visit_end_date <  o.fecha_ingreso
  )
)
,
-- PASO 5. CRITERIOS (todas las ventanas terminan en la fecha índice; EXISTS, no JOIN)
-- Inclusión 1 (ORDEN ALTERNATIVO): albúmina sérica en los 365 días previos
inc1 AS (
  SELECT l.* FROM lavado l
  WHERE EXISTS (SELECT 1 FROM measurement m
                WHERE m.person_id = l.person_id
                  AND m.measurement_concept_id = 3024561
                  AND m.measurement_date BETWEEN l.fecha_indice - INTERVAL 365 DAY AND l.fecha_indice)
),

-- Inclusión 2: creatinina (en sangre o sérica) en los 365 días previos
inc2 AS (
  SELECT i.* FROM inc1 i
  WHERE EXISTS (SELECT 1 FROM measurement m
                WHERE m.person_id = i.person_id
                  AND m.measurement_concept_id IN (3051825, 3016723)
                  AND m.measurement_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice)
),

-- Inclusión 3 (ORDEN ALTERNATIVO): al menos 2 visitas ambulatorias (9202) en los 365 días previos
inc3 AS (
  SELECT i.* FROM inc2 i
  WHERE (SELECT COUNT(*) FROM visit_occurrence v
         WHERE v.person_id = i.person_id
           AND v.visit_concept_id = 9202
           AND v.visit_start_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice) >= 2
),

-- Inclusión 4: tasa de filtración glomerular en los 365 días previos
inc4 AS (
  SELECT i.* FROM inc3 i
  WHERE EXISTS (SELECT 1 FROM measurement m
                WHERE m.person_id = i.person_id
                  AND m.measurement_concept_id = 46236952
                  AND m.measurement_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice)
),
-- Inclusión 5: multimorbilidad = al menos 2 diagnósticos distintos en los 730 días previos
inc5 AS (
  SELECT i.* FROM inc4 i
  WHERE (SELECT COUNT(DISTINCT c.condition_concept_id) FROM condition_occurrence c
         WHERE c.person_id = i.person_id
           AND c.condition_start_date BETWEEN i.fecha_indice - INTERVAL 730 DAY AND i.fecha_indice) >= 2
),
-- Exclusión 2: cáncer maligno (443392 y todos sus descendientes) en los 365 días previos
exc2 AS (
  SELECT i.* FROM inc5 i
  WHERE NOT EXISTS (
    SELECT 1 FROM condition_occurrence c
    JOIN concept_ancestor ca ON ca.descendant_concept_id = c.condition_concept_id
    WHERE ca.ancestor_concept_id = 443392
      AND c.person_id = i.person_id
      AND c.condition_start_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice)
)
,
-- PASO 6. ESTRATEGIA DE SALIDA
-- Salida = el mínimo entre (fecha índice + 90 días) y el fin de OBSERVATION_PERIOD.
-- (NOTA: la variable desenlace Muerte quedará  pendiente hasta cargar la tabla death de patients.csv.)
salida AS (
  SELECT person_id,
         fecha_indice AS cohort_start_date,
         LEAST(CAST(fecha_indice + INTERVAL 90 DAY AS DATE), fin_observacion) AS cohort_end_date
  FROM exc2
)

-- Conteo por paso con el orden alternativo
SELECT
  (SELECT COUNT(*) FROM lavado) AS lavado,
  (SELECT COUNT(*) FROM inc1)   AS albumina,
  (SELECT COUNT(*) FROM inc2)   AS creatinina,
  (SELECT COUNT(*) FROM inc3)   AS visitas_ambulatorias,
  (SELECT COUNT(*) FROM inc4)   AS tfg,
  (SELECT COUNT(*) FROM inc5)   AS multimorbilidad,
  (SELECT COUNT(*) FROM exc2)   AS final_sin_cancer;
