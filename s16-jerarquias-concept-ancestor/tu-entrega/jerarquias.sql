-- ============================================================
-- ACTIVIDAD 1: ancestros de demencia (4182210) con WITH RECURSIVE.
-- Hallazgo: 22 conceptos, raíz SNOMED CT Concept (4008453), profundidad 5 a 9.
-- ============================================================
-- Actividad 1: camino de demencia (4182210) hasta la raíz con WITH RECURSIVE
WITH RECURSIVE camino AS (
    SELECT 4182210 AS concept_id, 0 AS nivel
    UNION ALL
    SELECT cr.concept_id_2, c.nivel + 1
    FROM camino c
    JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
    WHERE cr.relationship_id = 'Is a'
      AND cr.invalid_reason IS NULL
      AND c.nivel < 20
)
SELECT ca.concept_id, co.concept_name,
       min(ca.nivel) AS nivel_min,
       max(ca.nivel) AS nivel_max
FROM camino ca
JOIN concept co ON co.concept_id = ca.concept_id
GROUP BY ca.concept_id, co.concept_name
ORDER BY nivel_min, nivel_max;

-- ============================================================
-- ACTIVIDAD 2: ancestros vía CONCEPT_ANCESTOR (16 filas).
-- Hallazgo: el recursivo da 22; los 6 faltantes son NO estándar
-- (CONCEPT_ANCESTOR solo guarda conceptos estándar).
-- ============================================================
-- Actividad 2: ancestros de demencia (4182210) con CONCEPT_ANCESTOR
SELECT ca.ancestor_concept_id AS concept_id, co.concept_name,
       ca.min_levels_of_separation AS nivel_min,
       ca.max_levels_of_separation AS nivel_max
FROM concept_ancestor ca
JOIN concept co ON co.concept_id = ca.ancestor_concept_id
WHERE ca.descendant_concept_id = 4182210
ORDER BY nivel_min, nivel_max;

-- 2b. Conceptos que están en el recursivo y no en CONCEPT_ANCESTOR (EXCEPT)
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

-- ============================================================
-- ACTIVIDAD 3: tipos de relación. 724 tipos; 124 jerárquicos;
-- 63 defines_ancestry; 55 cumplen ambos.
-- ============================================================
-- Actividad 3.1: tipos de relación y cuántos son jerárquicos o definen ancestros
SELECT count(*) AS total_relaciones,
       sum(CASE WHEN is_hierarchical = '1' THEN 1 ELSE 0 END) AS jerarquicas,
       sum(CASE WHEN defines_ancestry = '1' THEN 1 ELSE 0 END) AS definen_ancestros,
       sum(CASE WHEN is_hierarchical = '1' AND defines_ancestry = '1' THEN 1 ELSE 0 END) AS ambas
FROM relationship;

-- 3b. Relaciones que salen de metformina (1503297): 9 tipos;
-- solo 'RxNorm ing of' es jerárquica y define ancestría.
-- Actividad 3.2: relaciones distintas que salen de metformina (1503297)
SELECT cr.relationship_id, r.relationship_name,
       r.is_hierarchical, r.defines_ancestry,
       count(*) AS n
FROM concept_relationship cr
JOIN relationship r ON r.relationship_id = cr.relationship_id
WHERE cr.concept_id_1 = 1503297
  AND cr.invalid_reason IS NULL
GROUP BY cr.relationship_id, r.relationship_name, r.is_hierarchical, r.defines_ancestry
ORDER BY n DESC;

-- ============================================================
-- ACTIVIDAD 4: polijerarquía (min_levels <> max_levels). 15 casos.
-- ============================================================
-- Actividad 4.1: descendientes de demencia con más de un camino (poli-jerarquía)
SELECT ca.descendant_concept_id, co.concept_name,
       ca.min_levels_of_separation AS nivel_min,
       ca.max_levels_of_separation AS nivel_max
FROM concept_ancestor ca
JOIN concept co ON co.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = 4182210
  AND ca.min_levels_of_separation <> ca.max_levels_of_separation
ORDER BY nivel_max DESC
LIMIT 15;

-- 4b. Caminos de 4182210 a 4046090: uno de 3 niveles y otro de 4.
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

-- ============================================================
-- ACTIVIDAD 5: conteos con dos ramas IN (4182210, 378419).
-- A=294 (inflado por duplicados del JOIN), B=2, C=147 (correcto).
-- ============================================================
-- Actividad 5: tres formas de contar con dos ramas traslapadas
WITH registros AS (
    SELECT co.person_id, co.condition_concept_id, ca.ancestor_concept_id
    FROM condition_occurrence co
    JOIN concept_ancestor ca ON ca.descendant_concept_id = co.condition_concept_id
    WHERE ca.ancestor_concept_id IN (4182210, 378419)
)
SELECT count(*) AS a_filas_join,
       count(DISTINCT condition_concept_id) AS b_conceptos,
       count(DISTINCT person_id) AS c_pacientes
FROM registros;

-- ============================================================
-- ACTIVIDAD 6: ¿por qué entró este paciente? (pacientes 51, 117, 371).
-- Los tres entraron vía SNOMED 26929004 -> Alzheimer 378419.
-- ============================================================
-- Actividad 6: ¿por qué entró este paciente a la cohorte de demencia?
-- Para otro paciente, cambia solo el número en "parametros".
WITH parametros AS (
    SELECT 371 AS pid
)
SELECT co.person_id,
       co.condition_occurrence_id AS evento,
       co.condition_start_date AS fecha,
       co.condition_source_value AS codigo_fuente,
       co.condition_source_concept_id AS source_concept_id,
       src.concept_name AS concepto_fuente,
       co.condition_concept_id AS concepto_estandar_id,
       std.concept_name AS concepto_estandar,
       ca.ancestor_concept_id AS ancestro_del_set,
       anc.concept_name AS rama,
       ca.min_levels_of_separation AS niveles
FROM condition_occurrence co
JOIN parametros p ON co.person_id = p.pid
LEFT JOIN concept src ON src.concept_id = co.condition_source_concept_id
JOIN concept std ON std.concept_id = co.condition_concept_id
JOIN concept_ancestor ca ON ca.descendant_concept_id = co.condition_concept_id
JOIN concept anc ON anc.concept_id = ca.ancestor_concept_id
WHERE ca.ancestor_concept_id IN (4182210, 378419)
ORDER BY fecha;

-- ============================================================
-- ACTIVIDAD 7: conceptos muertos (invalid_reason D/U). 216 conceptos,
-- todos válidos; 0 pacientes ganados o perdidos.
-- ============================================================
-- Actividad 7: conceptos retirados dentro del concept set de demencia
SELECT c.invalid_reason, count(*) AS conceptos
FROM concept_ancestor ca
JOIN concept c ON c.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = 4182210
GROUP BY c.invalid_reason
ORDER BY conceptos DESC;

-- ============================================================
-- ACTIVIDAD 8: rendimiento. Las consultas V1 y V2 están en
-- act8_tiempos.py; resultados en tiempos.md (4.5 ms vs 2.2 ms).
-- ============================================================
