-- =============================================================================
-- Laboratorio 12 — Primeros pasos en OMOP CDM v5.4
-- Consultas de las actividades 5, 6, 7 y 8 sobre omop.duckdb
--
-- Cómo usar este fichero:
--   * Con Python:  python sql/correr_consultas.py          (todas)
--                  python sql/correr_consultas.py 6         (solo actividad 6)
--                  python sql/correr_consultas.py 6.5 7.2   (consultas concretas)
--   * Cada consulta empieza con una línea "-- >>> CONSULTA x.y | pregunta".
--     Esa línea es el SEPARADOR que usa correr_consultas.py. No la borres.
--
-- Reglas que seguimos en TODAS las consultas:
--   1) Nunca mostramos un concept_id sin su concept_name (JOIN a concept).
--   2) Los conteos epidemiológicos (personas) usan count(DISTINCT person_id).
--   3) Nada de SELECT * en los resultados finales: columnas explícitas.
--   4) LEFT JOIN a concept + COALESCE: si un concept_id no está en CONCEPT,
--      lo veremos como '(no está en CONCEPT)' en lugar de perder la fila.
-- =============================================================================


-- >>> CONSULTA 5.1 | ¿Qué porcentaje de registros tiene concept_id = 0 (sin mapear) en cada tabla y campo de concepto?
-- concept_id = 0 significa "No matching concept": el valor original existe,
-- pero no encontramos un concepto estándar OMOP para él.
-- Revisamos los campos de concepto principales de las 4 tablas obligatorias.
SELECT tabla, campo, total_filas, filas_con_cero,
       round(100.0 * filas_con_cero / total_filas, 2) AS pct_cero
FROM (
    SELECT 'person' AS tabla, 'gender_concept_id' AS campo,
           count(*) AS total_filas, count(*) FILTER (WHERE gender_concept_id = 0) AS filas_con_cero
    FROM person
    UNION ALL
    SELECT 'person', 'race_concept_id', count(*), count(*) FILTER (WHERE race_concept_id = 0) FROM person
    UNION ALL
    SELECT 'person', 'ethnicity_concept_id', count(*), count(*) FILTER (WHERE ethnicity_concept_id = 0) FROM person
    UNION ALL
    SELECT 'observation_period', 'period_type_concept_id', count(*), count(*) FILTER (WHERE period_type_concept_id = 0) FROM observation_period
    UNION ALL
    SELECT 'visit_occurrence', 'visit_concept_id', count(*), count(*) FILTER (WHERE visit_concept_id = 0) FROM visit_occurrence
    UNION ALL
    SELECT 'visit_occurrence', 'visit_type_concept_id', count(*), count(*) FILTER (WHERE visit_type_concept_id = 0) FROM visit_occurrence
    UNION ALL
    SELECT 'condition_occurrence', 'condition_concept_id', count(*), count(*) FILTER (WHERE condition_concept_id = 0) FROM condition_occurrence
    UNION ALL
    SELECT 'condition_occurrence', 'condition_source_concept_id', count(*), count(*) FILTER (WHERE condition_source_concept_id = 0) FROM condition_occurrence
    UNION ALL
    SELECT 'condition_occurrence', 'condition_type_concept_id', count(*), count(*) FILTER (WHERE condition_type_concept_id = 0) FROM condition_occurrence
) t
ORDER BY tabla, campo;


-- >>> CONSULTA 5.2 | (Opcional) ¿Y en las tablas opcionales drug_exposure y measurement?
-- Solo funciona si convertir.py creó esas tablas (INCLUIR_OPCIONALES = True).
SELECT 'drug_exposure' AS tabla, 'drug_concept_id' AS campo, count(*) AS total_filas,
       count(*) FILTER (WHERE drug_concept_id = 0) AS filas_con_cero,
       round(100.0 * count(*) FILTER (WHERE drug_concept_id = 0) / count(*), 2) AS pct_cero
FROM drug_exposure
UNION ALL
SELECT 'measurement', 'measurement_concept_id', count(*),
       count(*) FILTER (WHERE measurement_concept_id = 0),
       round(100.0 * count(*) FILTER (WHERE measurement_concept_id = 0) / count(*), 2)
FROM measurement
UNION ALL
SELECT 'measurement', 'unit_concept_id', count(*),
       count(*) FILTER (WHERE unit_concept_id = 0),
       round(100.0 * count(*) FILTER (WHERE unit_concept_id = 0) / count(*), 2)
FROM measurement;


-- >>> CONSULTA 5.3 | ¿A qué DOMINIO pertenecen los conceptos que acabaron en condition_occurrence?
-- En un ETL completo, cada registro va a la tabla de su dominio (Condition ->
-- condition_occurrence, Observation -> observation, ...). Nuestro ETL "a mano"
-- mete todo conditions.csv en condition_occurrence, así que aquí vemos cuántos
-- registros "deberían" estar en otra tabla (p. ej. hallazgos sociales).
SELECT COALESCE(c.domain_id, '(concept_id = 0, sin dominio)') AS dominio_del_concepto,
       count(*)                                         AS n_registros,
       count(DISTINCT co.person_id)                     AS n_personas,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct_registros
FROM condition_occurrence co
LEFT JOIN concept c ON c.concept_id = co.condition_concept_id AND co.condition_concept_id <> 0
GROUP BY 1
ORDER BY n_registros DESC;


-- >>> CONSULTA 5.4 | ¿Qué códigos SNOMED de Synthea se quedaron sin concepto estándar (los 15 más frecuentes)?
-- condition_source_value es el código original de Synthea. Si
-- condition_source_concept_id también es 0, el código ni siquiera está en
-- CONCEPT (¿faltó marcar SNOMED en ATHENA? ¿código muy nuevo?).
SELECT co.condition_source_value                               AS codigo_synthea,
       co.condition_source_concept_id                          AS source_concept_id,
       COALESCE(src.concept_name, '(no está en CONCEPT)')      AS source_concept_name,
       count(*)                                                AS n_registros,
       count(DISTINCT co.person_id)                            AS n_personas
FROM condition_occurrence co
LEFT JOIN concept src ON src.concept_id = co.condition_source_concept_id AND co.condition_source_concept_id <> 0
WHERE co.condition_concept_id = 0
GROUP BY 1, 2, 3
ORDER BY n_registros DESC
LIMIT 15;


-- >>> CONSULTA 5.5 | ¿Qué clases de encuentro de Synthea quedaron con visit_concept_id = 0?
-- visit_source_value guarda el ENCOUNTERCLASS original (virtual, home, snf, hospice...).
SELECT vo.visit_source_value          AS encounterclass_synthea,
       count(*)                       AS n_visitas,
       count(DISTINCT vo.person_id)   AS n_personas
FROM visit_occurrence vo
WHERE vo.visit_concept_id = 0
GROUP BY 1
ORDER BY n_visitas DESC;


-- >>> CONSULTA 6.1 | ¿Cuántas personas hay en la base de datos?
SELECT count(DISTINCT person_id) AS n_personas
FROM person;


-- >>> CONSULTA 6.2 | ¿Cómo se distribuyen las personas por sexo?
SELECT p.gender_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')               AS sexo,
       count(DISTINCT p.person_id)                                     AS n_personas,
       round(100.0 * count(DISTINCT p.person_id)
             / (SELECT count(DISTINCT person_id) FROM person), 1)      AS pct
FROM person p
LEFT JOIN concept c ON c.concept_id = p.gender_concept_id
GROUP BY 1, 2
ORDER BY n_personas DESC;


-- >>> CONSULTA 6.3 | ¿Cómo se distribuyen las personas por década de nacimiento y sexo?
-- Agrupamos el año de nacimiento por décadas (1950, 1960, ...) para que la
-- tabla sea legible; el sexo siempre con su concept_name.
SELECT (p.year_of_birth // 10) * 10                       AS decada_nacimiento,
       p.gender_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')   AS sexo,
       count(DISTINCT p.person_id)                         AS n_personas
FROM person p
LEFT JOIN concept c ON c.concept_id = p.gender_concept_id
GROUP BY 1, 2, 3
ORDER BY decada_nacimiento, sexo;


-- >>> CONSULTA 6.4 | ¿Cuál es la mediana de días de observación por persona?
-- Sumamos los días de todos los periodos de cada persona (en nuestro ETL hay
-- uno por persona) y luego calculamos mediana, media, mínimo y máximo.
-- Solo personas que están en PERSON: en Eunomia GiBleed hay periodos de
-- observación de personas que NO están en person (¡revisa siempre esto!).
WITH dias_por_persona AS (
    SELECT op.person_id,
           sum(date_diff('day', op.observation_period_start_date, op.observation_period_end_date)) AS dias
    FROM observation_period op
    WHERE op.person_id IN (SELECT person_id FROM person)
    GROUP BY op.person_id
)
SELECT count(DISTINCT person_id)          AS n_personas_con_periodo,
       median(dias)                       AS mediana_dias,
       round(median(dias) / 365.25, 1)    AS mediana_anios,
       round(avg(dias), 1)                AS media_dias,
       min(dias)                          AS min_dias,
       max(dias)                          AS max_dias
FROM dias_por_persona;


-- >>> CONSULTA 6.5 | ¿Cuáles son los 20 diagnósticos con más personas afectadas?
-- Contamos PERSONAS distintas (prevalencia), no eventos. También mostramos el
-- número de eventos para ver la diferencia. Excluimos el concepto 0 ("No
-- matching concept"): no es un diagnóstico (ya lo medimos en la actividad 5).
-- Ojo a la columna dominio: los hallazgos sociales de Synthea (empleo,
-- estrés, educación...) son del dominio Observation, no Condition.
SELECT co.condition_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')   AS diagnostico,
       COALESCE(c.domain_id, '-')                         AS dominio,
       count(DISTINCT co.person_id)                        AS n_personas,
       round(100.0 * count(DISTINCT co.person_id)
             / (SELECT count(DISTINCT person_id) FROM person), 1) AS pct_personas,
       count(*)                                            AS n_eventos
FROM condition_occurrence co
LEFT JOIN concept c ON c.concept_id = co.condition_concept_id
WHERE co.condition_concept_id <> 0
GROUP BY 1, 2, 3
ORDER BY n_personas DESC, n_eventos DESC
LIMIT 20;


-- >>> CONSULTA 6.6 | ¿Cuántas visitas tiene, en promedio, cada persona?
-- Dos denominadores: todas las personas de person, y solo las que tienen
-- al menos una visita.
SELECT count(*)                                                       AS n_visitas,
       (SELECT count(DISTINCT person_id) FROM person)                 AS n_personas_total,
       count(DISTINCT person_id)                                      AS n_personas_con_visita,
       round(count(*) / (SELECT count(DISTINCT person_id) FROM person), 2) AS visitas_por_persona_total,
       round(count(*) / count(DISTINCT person_id), 2)                AS visitas_por_persona_con_visita
FROM visit_occurrence;


-- >>> CONSULTA 6.7 | ¿Cuántas visitas hay por tipo de visita y cuántas tiene en promedio cada persona?
SELECT vo.visit_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')   AS tipo_visita,
       count(*)                                            AS n_visitas,
       count(DISTINCT vo.person_id)                        AS n_personas,
       round(count(*) / count(DISTINCT vo.person_id), 2)   AS visitas_por_persona_con_ese_tipo,
       round(count(*) / (SELECT count(DISTINCT person_id) FROM person), 2) AS visitas_por_persona_total
FROM visit_occurrence vo
LEFT JOIN concept c ON c.concept_id = vo.visit_concept_id
GROUP BY 1, 2
ORDER BY n_visitas DESC;


-- >>> CONSULTA 7.1 | ¿Qué conceptos de CONCEPT se llaman como la condición elegida (hipertensión esencial)?
-- Buscamos por NOMBRE, no por un concept_id de memoria. Cambia el texto de
-- 'buscar' si quieres otra condición (p. ej. 'Prediabetes').
WITH parametros AS (SELECT 'Essential hypertension' AS buscar)
SELECT c.concept_id, c.concept_name, c.vocabulary_id, c.concept_code,
       c.domain_id, COALESCE(c.standard_concept, '-') AS standard_concept,
       COALESCE(c.invalid_reason, '-')                AS invalid_reason
FROM concept c, parametros
WHERE c.concept_name ILIKE parametros.buscar
  AND c.domain_id = 'Condition'
ORDER BY c.standard_concept NULLS LAST, c.vocabulary_id;


-- >>> CONSULTA 7.2 | ¿Cuántas personas tienen la condición si contamos por condition_concept_id y cuántas si contamos por condition_source_value?
-- A) Por concepto estándar: condition_concept_id = concepto estándar con ese nombre.
-- B) Por código fuente: condition_source_value = código SNOMED de ese mismo
--    concepto estándar (lo que haría alguien que busca "el código" en el CSV).
-- C) Por código fuente "amplio": cualquier código SNOMED cuyo nombre coincida
--    (incluye códigos antiguos / no estándar).
-- Si A y B difieren, es porque hay otros códigos de origen que "mapean a"
-- (Maps to) ese mismo concepto estándar.
WITH parametros AS (SELECT 'Essential hypertension' AS buscar),
estandar AS (
    SELECT c.concept_id, c.concept_code
    FROM concept c, parametros
    WHERE c.concept_name ILIKE parametros.buscar AND c.domain_id = 'Condition'
      AND c.standard_concept = 'S'
),
codigos_amplios AS (
    SELECT c.concept_code
    FROM concept c, parametros
    WHERE c.concept_name ILIKE parametros.buscar AND c.vocabulary_id = 'SNOMED'
)
SELECT 'A) por condition_concept_id (estándar)' AS metodo,
       count(DISTINCT co.person_id) AS n_personas, count(*) AS n_eventos
FROM condition_occurrence co
WHERE co.condition_concept_id IN (SELECT concept_id FROM estandar)
UNION ALL
SELECT 'B) por condition_source_value (código del estándar)',
       count(DISTINCT co.person_id), count(*)
FROM condition_occurrence co
WHERE co.condition_source_value IN (SELECT concept_code FROM estandar)
UNION ALL
SELECT 'C) por condition_source_value (todos los códigos SNOMED con ese nombre)',
       count(DISTINCT co.person_id), count(*)
FROM condition_occurrence co
WHERE co.condition_source_value IN (SELECT concept_code FROM codigos_amplios);


-- >>> CONSULTA 7.3 | ¿Qué códigos de origen alimentan cada concepto estándar de la condición elegida?
-- Tabla "de dónde viene": código fuente -> concepto fuente -> concepto estándar.
WITH parametros AS (SELECT 'Essential hypertension' AS buscar),
estandar AS (
    SELECT c.concept_id, c.concept_code
    FROM concept c, parametros
    WHERE c.concept_name ILIKE parametros.buscar AND c.domain_id = 'Condition'
      AND c.standard_concept = 'S'
)
SELECT co.condition_source_value                                AS codigo_fuente,
       COALESCE(src.concept_name, '(no está en CONCEPT)')       AS nombre_fuente,
       co.condition_concept_id,
       COALESCE(std.concept_name, '(no está en CONCEPT)')       AS nombre_estandar,
       count(DISTINCT co.person_id)                              AS n_personas,
       count(*)                                                  AS n_eventos
FROM condition_occurrence co
LEFT JOIN concept src ON src.concept_id = co.condition_source_concept_id
LEFT JOIN concept std ON std.concept_id = co.condition_concept_id
WHERE co.condition_concept_id IN (SELECT concept_id FROM estandar)
   OR co.condition_source_value IN (SELECT concept_code FROM estandar)
GROUP BY 1, 2, 3, 4
ORDER BY n_eventos DESC;


-- >>> CONSULTA 7.4 | (Extra) ¿Cuántas personas tienen CUALQUIER trastorno hipertensivo usando la jerarquía (CONCEPT_ANCESTOR)?
-- 'Hypertensive disorder' es un concepto "padre"; CONCEPT_ANCESTOR nos da
-- todos sus descendientes (hipertensión esencial, secundaria, renal, ...).
-- Así se cuenta en OHDSI: por concepto estándar + descendientes.
WITH padre AS (
    SELECT concept_id FROM concept
    WHERE concept_name ILIKE 'Hypertensive disorder'
      AND domain_id = 'Condition' AND standard_concept = 'S'
),
descendientes AS (
    SELECT ca.descendant_concept_id AS concept_id
    FROM concept_ancestor ca JOIN padre ON padre.concept_id = ca.ancestor_concept_id
)
SELECT co.condition_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')  AS concepto,
       count(DISTINCT co.person_id)                       AS n_personas,
       count(*)                                           AS n_eventos
FROM condition_occurrence co
JOIN descendientes d ON d.concept_id = co.condition_concept_id
LEFT JOIN concept c  ON c.concept_id = co.condition_concept_id
GROUP BY 1, 2
ORDER BY n_personas DESC;


-- >>> CONSULTA 7.5 | (Extra) ¿Qué códigos de Synthea CAMBIAN de concepto al mapear (concepto fuente distinto del estándar)?
-- Útil para elegir una condición donde contar por código fuente y por
-- concepto estándar dé resultados distintos (códigos antiguos o no estándar
-- que 'Maps to' otro concepto). Si sale vacía, todos los códigos SNOMED de
-- Synthea ya eran estándar y A = B en la consulta 7.2.
SELECT co.condition_source_value                                AS codigo_fuente,
       COALESCE(src.concept_name, '(no está en CONCEPT)')       AS nombre_fuente,
       COALESCE(src.standard_concept, '-')                      AS fuente_es_estandar,
       co.condition_concept_id,
       COALESCE(std.concept_name, '(no está en CONCEPT)')       AS nombre_estandar,
       COALESCE(std.domain_id, '-')                             AS dominio_estandar,
       count(DISTINCT co.person_id)                              AS n_personas,
       count(*)                                                  AS n_eventos
FROM condition_occurrence co
JOIN concept src      ON src.concept_id = co.condition_source_concept_id
LEFT JOIN concept std ON std.concept_id = co.condition_concept_id
WHERE co.condition_concept_id <> 0
  AND co.condition_concept_id <> co.condition_source_concept_id
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY n_personas DESC
LIMIT 20;


-- >>> CONSULTA 8.1 | ¿Cuántos eventos de condición hay en total y cuántos caen dentro de un observation_period de la persona?
-- Un evento está "dentro" si su fecha de inicio está entre el inicio y el fin
-- de algún periodo de observación de esa misma persona.
WITH marcado AS (
    SELECT co.condition_occurrence_id, co.person_id,
           EXISTS (
               SELECT 1 FROM observation_period op
               WHERE op.person_id = co.person_id
                 AND co.condition_start_date BETWEEN op.observation_period_start_date
                                                 AND op.observation_period_end_date
           ) AS dentro
    FROM condition_occurrence co
)
SELECT count(*)                                         AS eventos_total,
       count(*) FILTER (WHERE dentro)                   AS eventos_dentro,
       count(*) FILTER (WHERE NOT dentro)               AS eventos_fuera,
       round(100.0 * count(*) FILTER (WHERE NOT dentro) / count(*), 2) AS pct_diferencia,
       count(DISTINCT person_id)                        AS personas_total,
       count(DISTINCT person_id) FILTER (WHERE dentro)  AS personas_con_eventos_dentro
FROM marcado;


-- >>> CONSULTA 8.2 | Los eventos que quedan fuera, ¿cuántos días antes del inicio o después del fin del periodo están?
-- (Pensada para nuestro ETL, que tiene UN periodo por persona.)
-- Sirve para entender la causa (p. ej. 1 día antes = efecto de zona horaria:
-- Synthea escribe la fecha de la condición en hora local y la del encuentro en UTC).
SELECT CASE WHEN co.condition_start_date < op.observation_period_start_date
            THEN 'antes del inicio' ELSE 'después del fin' END             AS posicion,
       CASE WHEN co.condition_start_date < op.observation_period_start_date
            THEN date_diff('day', co.condition_start_date, op.observation_period_start_date)
            ELSE date_diff('day', op.observation_period_end_date, co.condition_start_date)
       END                                                                  AS dias_fuera,
       count(*)                                                             AS n_eventos,
       count(DISTINCT co.person_id)                                         AS n_personas
FROM condition_occurrence co
JOIN observation_period op ON op.person_id = co.person_id
WHERE co.condition_start_date NOT BETWEEN op.observation_period_start_date
                                      AND op.observation_period_end_date
GROUP BY 1, 2
ORDER BY n_eventos DESC
LIMIT 15;
