-- =============================================================================
-- Laboratorio 13 — Exposición a fármacos y laboratorios
-- OMOP CDM v5.4: DRUG_EXPOSURE, MEASUREMENT y tablas derivadas (eras, PDC)
--
-- Base de datos: ~/s12-omop-cdm-introduccion/omop.duckdb (la del Lab 12).
-- Las tablas NUEVAS se guardan en el esquema "results" (CREATE SCHEMA results)
-- para no mezclar lo derivado con las tablas OMOP originales. Si quieres
-- empezar de cero:  DROP SCHEMA results CASCADE;
--
-- Cómo usarlo:
--   python sql/correr_farmacoepi.py            -> todo, en orden
--   python sql/correr_farmacoepi.py 4          -> solo la actividad 4
--   python sql/correr_farmacoepi.py 0 5.2      -> parámetros + consulta 5.2
-- Separador de cada consulta (no lo borres):
--   -- >>> CONSULTA x.y | ¿pregunta?
-- Las consultas marcadas [CREA ...] crean una tabla en results; las demás
-- solo leen. El orden importa: 0.1 (parámetros) va primero; 4.x necesita
-- 4.1; 5.x y 10.x necesitan 4.1-4.2; 7.2-7.3 necesitan 7.1; 8.2-8.4 necesitan 8.1.
--
-- Reglas del curso:
--   * Nunca mostramos un concept_id sin su concept_name.
--   * Personas siempre con count(DISTINCT person_id).
--   * Nada de SELECT * en resultados finales.
-- =============================================================================


-- >>> CONSULTA 0.1 | [CREA results.parametros] ¿Qué ingrediente, analitos y ventanas usaremos en todo el lab?
-- Una sola fila con todas las decisiones. Si quieres otro ingrediente o
-- analito, cambia SOLO esta consulta y vuelve a ejecutar todo.
--   ingrediente  : lisinopril (IECA, uso crónico -> tiene sentido el PDC;
--                  en Synthea aparece como fármaco clínico "lisinopril 10 MG
--                  Oral Tablet", nunca como ingrediente -> sirve para la act. 3)
--   analito basal: presión arterial sistólica (LOINC 8480-6), lógico para
--                  un antihipertensivo (actividad 10)
--   glucosa      : LOINC 2339-0 "Glucose [Mass/volume] in Blood" (act. 7)
CREATE SCHEMA IF NOT EXISTS results;
CREATE OR REPLACE TABLE results.parametros AS
SELECT
    (SELECT min(concept_id) FROM concept
      WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Ingredient'
        AND standard_concept = 'S' AND lower(concept_name) = 'lisinopril')   AS ingrediente_id,
    (SELECT min(concept_id) FROM concept
      WHERE vocabulary_id = 'LOINC' AND concept_code = '8480-6')             AS analito_basal_id,
    (SELECT min(concept_id) FROM concept
      WHERE vocabulary_id = 'LOINC' AND concept_code = '2339-0')             AS glucosa_id,
    30      AS ventana_persistencia_dias,   -- drug_era / condition_era (convención OHDSI)
    365     AS seguimiento_pdc_dias,        -- 1 año desde la primera exposición
    90      AS ventana_basal_dias,          -- ±90 días alrededor de la fecha índice
    29      AS dias_si_falta_fin,           -- THEMIS: receta escrita sin fin -> inicio + 29
    18.016  AS factor_glucosa,              -- mg/dL = mmol/L x 18.016 (PM glucosa 180.16 g/mol)
    0.30    AS fraccion_simulada;           -- 30 % de glucosas se "pasan" a mmol/L (act. 7)
SELECT p.ingrediente_id,   ci.concept_name AS ingrediente,
       p.analito_basal_id, cb.concept_name AS analito_basal,
       p.glucosa_id,       cg.concept_name AS glucosa,
       p.ventana_persistencia_dias, p.seguimiento_pdc_dias, p.ventana_basal_dias
FROM results.parametros p
LEFT JOIN concept ci ON ci.concept_id = p.ingrediente_id
LEFT JOIN concept cb ON cb.concept_id = p.analito_basal_id
LEFT JOIN concept cg ON cg.concept_id = p.glucosa_id;


-- =============================================================================
-- ACTIVIDAD 1 — Tipo de registro de fármaco
-- =============================================================================

-- >>> CONSULTA 1.1 | ¿Cómo se distribuye drug_type_concept_id (prescripción, dispensación, administración...)?
-- En nuestro ETL pusimos 32817 "EHR" a todo. Synthea medications.csv son
-- en realidad prescripciones (órdenes del médico), no dispensaciones de
-- farmacia ni administraciones. Un concepto más preciso sería
-- "EHR prescription" (Type Concept); compruébalo en ATHENA.
SELECT d.drug_type_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')   AS tipo_registro,
       count(*)                                           AS n_registros,
       count(DISTINCT d.person_id)                        AS n_personas,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM drug_exposure d
LEFT JOIN concept c ON c.concept_id = d.drug_type_concept_id
GROUP BY 1, 2
ORDER BY n_registros DESC;


-- =============================================================================
-- ACTIVIDAD 2 — Caracterizar DRUG_EXPOSURE
-- =============================================================================

-- >>> CONSULTA 2.1 | ¿Cuáles son los 20 INGREDIENTES con más pacientes (subiendo por la jerarquía con CONCEPT_ANCESTOR)?
-- drug_concept_id suele ser un fármaco clínico (dosis + forma). Para hablar
-- de "principios activos" subimos al ancestro de clase 'Ingredient'.
-- Un combinado (p. ej. amoxicilina/clavulánico) cuenta en AMBOS ingredientes.
SELECT i.concept_id                    AS ingrediente_id,
       i.concept_name                  AS ingrediente,
       count(DISTINCT d.person_id)     AS n_personas,
       count(*)                        AS n_registros,
       count(DISTINCT d.drug_concept_id) AS n_productos_distintos
FROM drug_exposure d
JOIN concept_ancestor ca ON ca.descendant_concept_id = d.drug_concept_id
JOIN concept i           ON i.concept_id = ca.ancestor_concept_id
WHERE i.concept_class_id = 'Ingredient'
  AND i.standard_concept = 'S'
GROUP BY 1, 2
ORDER BY n_personas DESC, n_registros DESC
LIMIT 20;


-- >>> CONSULTA 2.2 | ¿Qué valores tiene days_supply? (¿está vacío?)
-- Nuestro convertir.py NO calculó days_supply (Synthea no lo trae) y THEMIS
-- dice que se deje vacío si la fuente no lo da (no inventarlo).
SELECT CASE WHEN days_supply IS NULL THEN '(NULL)'
            WHEN days_supply <= 0   THEN '<= 0'
            WHEN days_supply <= 30  THEN '1-30'
            WHEN days_supply <= 90  THEN '31-90'
            ELSE '> 90' END                               AS days_supply,
       count(*)                                           AS n_registros,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM drug_exposure
GROUP BY 1
ORDER BY n_registros DESC;


-- >>> CONSULTA 2.3 | Como no hay days_supply, ¿cuánto duran las exposiciones según sus fechas?
-- duración = drug_exposure_end_date - drug_exposure_start_date.
-- verbatim_end_date guarda el STOP original de Synthea: si es NULL, el
-- ETL rellenó end_date = start_date (la duración 0 es artificial).
SELECT CASE WHEN verbatim_end_date IS NULL THEN 'sin STOP en Synthea (fin = inicio)'
            ELSE 'con STOP en Synthea' END                AS origen_fecha_fin,
       CASE WHEN dur < 0 THEN '0) NEGATIVA (end < start: error)'
            WHEN dur = 0 THEN 'a) 0 días'
            WHEN dur <= 7 THEN 'b) 1-7'
            WHEN dur <= 30 THEN 'c) 8-30'
            WHEN dur <= 90 THEN 'd) 31-90'
            WHEN dur <= 365 THEN 'e) 91-365'
            ELSE 'f) > 365' END                           AS duracion,
       count(*)                                           AS n_registros,
       count(DISTINCT person_id)                          AS n_personas,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM (SELECT person_id, verbatim_end_date,
             date_diff('day', drug_exposure_start_date, drug_exposure_end_date) AS dur
      FROM drug_exposure) t
GROUP BY 1, 2
ORDER BY 1, 2;


-- >>> CONSULTA 2.4 | ¿Qué % de filas tiene end_date nulo, end_date = start_date, end < start, o drug_concept_id = 0?
SELECT count(*)                                                                         AS n_registros,
       round(100.0 * count(*) FILTER (WHERE drug_exposure_end_date IS NULL) / count(*), 2) AS pct_end_nulo,
       round(100.0 * count(*) FILTER (WHERE drug_exposure_end_date = drug_exposure_start_date) / count(*), 2) AS pct_end_igual_start,
       round(100.0 * count(*) FILTER (WHERE drug_exposure_end_date < drug_exposure_start_date) / count(*), 2) AS pct_end_antes_start,
       round(100.0 * count(*) FILTER (WHERE verbatim_end_date IS NULL) / count(*), 2)    AS pct_sin_stop_original,
       round(100.0 * count(*) FILTER (WHERE drug_concept_id = 0) / count(*), 2)          AS pct_concept_0,
       round(100.0 * count(*) FILTER (WHERE days_supply IS NULL) / count(*), 2)          AS pct_days_supply_nulo,
       round(100.0 * count(*) FILTER (WHERE quantity IS NULL) / count(*), 2)             AS pct_quantity_nulo
FROM drug_exposure;


-- >>> CONSULTA 2.5 | ¿Qué productos tienen fin = inicio (administraciones de un día vs. recetas sin STOP)?
SELECT d.drug_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')    AS producto,
       count(*) FILTER (WHERE d.verbatim_end_date IS NULL) AS n_sin_stop,
       count(*) FILTER (WHERE d.verbatim_end_date IS NOT NULL
                          AND d.drug_exposure_end_date = d.drug_exposure_start_date) AS n_stop_mismo_dia,
       count(DISTINCT d.person_id)                         AS n_personas
FROM drug_exposure d
LEFT JOIN concept c ON c.concept_id = d.drug_concept_id
WHERE d.drug_exposure_end_date = d.drug_exposure_start_date
GROUP BY 1, 2
ORDER BY n_sin_stop + n_stop_mismo_dia DESC
LIMIT 15;


-- >>> CONSULTA 2.6 | ¿Hay registros duplicados por mapeos 1->N (mismo paciente, fecha y código fuente con varios drug_concept_id)?
-- Explica por qué drug_exposure puede tener algunas filas más que medications.csv.
SELECT d.drug_source_value                                 AS codigo_rxnorm_fuente,
       COALESCE(s.concept_name, '(no está en CONCEPT)')    AS producto_fuente,
       count(DISTINCT d.drug_concept_id)                   AS n_conceptos_destino,
       string_agg(DISTINCT COALESCE(c.concept_name, '?'), ' | ') AS conceptos_destino,
       count(*)                                            AS n_registros
FROM drug_exposure d
LEFT JOIN concept s ON s.concept_id = d.drug_source_concept_id
LEFT JOIN concept c ON c.concept_id = d.drug_concept_id
GROUP BY 1, 2
HAVING count(DISTINCT d.drug_concept_id) > 1
ORDER BY n_registros DESC
LIMIT 15;


-- =============================================================================
-- ACTIVIDAD 3 — Pacientes expuestos a un ingrediente: concepto exacto vs. jerarquía
-- =============================================================================

-- >>> CONSULTA 3.1 | ¿Cuántas personas tienen drug_concept_id = el INGREDIENTE exacto vs. cualquier descendiente (CONCEPT_ANCESTOR)?
SELECT ci.concept_name                                                   AS ingrediente,
       'A) drug_concept_id = ingrediente (exacto)'                       AS metodo,
       count(DISTINCT d.person_id)                                       AS n_personas,
       count(d.drug_exposure_id)                                         AS n_registros
FROM results.parametros p
JOIN concept ci ON ci.concept_id = p.ingrediente_id
LEFT JOIN drug_exposure d ON d.drug_concept_id = p.ingrediente_id
GROUP BY 1, 2
UNION ALL
SELECT ci.concept_name,
       'B) descendientes del ingrediente (concept_ancestor)',
       count(DISTINCT d.person_id),
       count(d.drug_exposure_id)
FROM results.parametros p
JOIN concept ci ON ci.concept_id = p.ingrediente_id
JOIN concept_ancestor ca ON ca.ancestor_concept_id = p.ingrediente_id
LEFT JOIN drug_exposure d ON d.drug_concept_id = ca.descendant_concept_id
GROUP BY 1, 2;


-- >>> CONSULTA 3.2 | ¿Qué productos concretos (descendientes) aportan esos pacientes?
SELECT d.drug_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')  AS producto,
       c.concept_class_id                                AS clase,
       ca.min_levels_of_separation                       AS niveles_desde_ingrediente,
       count(DISTINCT d.person_id)                       AS n_personas,
       count(*)                                          AS n_registros
FROM results.parametros p
JOIN concept_ancestor ca ON ca.ancestor_concept_id = p.ingrediente_id
JOIN drug_exposure d     ON d.drug_concept_id = ca.descendant_concept_id
LEFT JOIN concept c      ON c.concept_id = d.drug_concept_id
GROUP BY 1, 2, 3, 4
ORDER BY n_personas DESC;


-- =============================================================================
-- ACTIVIDAD 4 — DRUG_ERA a mano (gaps and islands, ventana de 30 días)
-- =============================================================================

-- >>> CONSULTA 4.1 | [CREA results.exposicion_ingrediente] ¿Qué exposiciones al ingrediente hay y cuál es su fecha fin "efectiva"?
-- Supuestos (documéntalos en el reporte):
--   * Si Synthea no tenía STOP (verbatim_end_date NULL): fin = inicio + 29
--     (THEMIS, receta escrita sin fecha fin).
--   * Si había STOP: en Synthea el STOP de una receta coincide con el START
--     de la siguiente, así que tomamos los días cubiertos como [inicio, STOP)
--     -> dias = STOP - inicio (mínimo 1 día).
--   * fin_cobertura = inicio + dias - 1 (último día cubierto, inclusive).
--   * Quitamos duplicados exactos (mismo paciente, inicio y fin) que pueden
--     venir de mapeos 1->N.
CREATE OR REPLACE TABLE results.exposicion_ingrediente AS
SELECT DISTINCT person_id, ingrediente_id, inicio, dias,
       inicio + (dias - 1)  AS fin_cobertura,
       fin_imputado
FROM (
    SELECT d.person_id,
           p.ingrediente_id,
           d.drug_exposure_start_date                                     AS inicio,
           CAST(CASE WHEN d.verbatim_end_date IS NULL THEN p.dias_si_falta_fin + 1
                     ELSE greatest(date_diff('day', d.drug_exposure_start_date, d.drug_exposure_end_date), 1)
                END AS INTEGER)                                           AS dias,
           (d.verbatim_end_date IS NULL)                                  AS fin_imputado
    FROM drug_exposure d
    JOIN results.parametros p ON TRUE
    JOIN concept_ancestor ca  ON ca.ancestor_concept_id = p.ingrediente_id
                             AND ca.descendant_concept_id = d.drug_concept_id
) t;
SELECT count(*)                          AS n_exposiciones,
       count(DISTINCT person_id)         AS n_personas,
       count(*) FILTER (WHERE fin_imputado) AS n_fin_imputado,
       median(dias)                      AS mediana_dias
FROM results.exposicion_ingrediente;


-- >>> CONSULTA 4.2 | [CREA results.cobertura_ingrediente] ¿Qué tramos continuos de cobertura hay (fusionando solapes y días contiguos)?
-- "Gaps and islands" con hueco 0: una exposición empieza tramo nuevo si
-- comienza después del día siguiente al mayor fin anterior.
CREATE OR REPLACE TABLE results.cobertura_ingrediente AS
WITH ordenado AS (
    SELECT person_id, inicio, fin_cobertura,
           max(fin_cobertura) OVER (PARTITION BY person_id ORDER BY inicio, fin_cobertura
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS max_fin_previo
    FROM results.exposicion_ingrediente
),
marcas AS (
    SELECT *, CASE WHEN max_fin_previo IS NULL OR inicio > max_fin_previo + 1 THEN 1 ELSE 0 END AS nuevo
    FROM ordenado
),
islas AS (
    SELECT *, sum(nuevo) OVER (PARTITION BY person_id ORDER BY inicio, fin_cobertura
                               ROWS UNBOUNDED PRECEDING) AS tramo
    FROM marcas
)
SELECT person_id, tramo, min(inicio) AS inicio, max(fin_cobertura) AS fin
FROM islas
GROUP BY person_id, tramo;
SELECT count(*) AS n_tramos, count(DISTINCT person_id) AS n_personas FROM results.cobertura_ingrediente;


-- >>> CONSULTA 4.3 | [CREA results.drug_era_ingrediente] ¿Qué eras de exposición salen con una ventana de persistencia de 30 días?
-- Igual que antes pero permitiendo huecos de hasta 30 días entre tramos.
-- Columnas como la tabla DRUG_ERA oficial v5.4. gap_days = días de la era
-- sin cobertura.
CREATE OR REPLACE TABLE results.drug_era_ingrediente AS
WITH ordenado AS (
    SELECT c.person_id, c.inicio, c.fin, p.ventana_persistencia_dias AS v,
           max(c.fin) OVER (PARTITION BY c.person_id ORDER BY c.inicio
                            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS max_fin_previo
    FROM results.cobertura_ingrediente c, results.parametros p
),
islas AS (
    SELECT *, sum(CASE WHEN max_fin_previo IS NULL OR inicio > max_fin_previo + v THEN 1 ELSE 0 END)
              OVER (PARTITION BY person_id ORDER BY inicio ROWS UNBOUNDED PRECEDING) AS era
    FROM ordenado
),
eras AS (
    SELECT person_id, era, min(inicio) AS drug_era_start_date, max(fin) AS drug_era_end_date,
           sum(date_diff('day', inicio, fin) + 1) AS dias_cubiertos
    FROM islas GROUP BY person_id, era
)
SELECT row_number() OVER (ORDER BY e.person_id, e.drug_era_start_date) AS drug_era_id,
       e.person_id,
       p.ingrediente_id                                        AS drug_concept_id,
       e.drug_era_start_date,
       e.drug_era_end_date,
       (SELECT count(*) FROM results.exposicion_ingrediente x
         WHERE x.person_id = e.person_id
           AND x.inicio BETWEEN e.drug_era_start_date AND e.drug_era_end_date) AS drug_exposure_count,
       (date_diff('day', e.drug_era_start_date, e.drug_era_end_date) + 1 - e.dias_cubiertos)::INTEGER AS gap_days
FROM eras e, results.parametros p;
SELECT count(*)                         AS n_eras,
       count(DISTINCT person_id)        AS n_personas,
       round(count(*) / count(DISTINCT person_id), 2) AS eras_por_persona,
       median(date_diff('day', drug_era_start_date, drug_era_end_date) + 1) AS mediana_dias_era,
       sum(drug_exposure_count)         AS exposiciones_incluidas,
       sum(gap_days)                    AS total_gap_days,
       (SELECT count(*) FROM results.cobertura_ingrediente) AS n_tramos_sin_huecos_4_2
FROM results.drug_era_ingrediente;


-- >>> CONSULTA 4.4 | ¿Cómo se reparten las eras del ingrediente por duración? (con su nombre)
SELECT c.concept_name                                    AS ingrediente,
       CASE WHEN dias <= 30 THEN 'a) <= 30 días'
            WHEN dias <= 90 THEN 'b) 31-90'
            WHEN dias <= 365 THEN 'c) 91-365'
            WHEN dias <= 1825 THEN 'd) 1-5 años'
            ELSE 'e) > 5 años' END                       AS duracion_era,
       count(*)                                          AS n_eras,
       count(DISTINCT person_id)                         AS n_personas
FROM (SELECT person_id, drug_concept_id,
             date_diff('day', drug_era_start_date, drug_era_end_date) + 1 AS dias
      FROM results.drug_era_ingrediente) e
JOIN concept c ON c.concept_id = e.drug_concept_id
GROUP BY 1, 2
ORDER BY 2;


-- >>> CONSULTA 4.5 | ¿Existe una tabla DRUG_ERA derivada en la base con la que comparar?
-- Nuestro convertir.py no creó drug_era (ni condition_era). Normalmente la
-- generan scripts de OHDSI (en R/SQL) tras el ETL. Por eso comparamos con
-- la versión "de todos los ingredientes" de la consulta 4.6.
-- Si sale vacía o solo con esquema 'results', NO había DRUG_ERA del ETL.
SELECT t.tabla_buscada,
       COALESCE(i.table_schema, '-')                                  AS esquema,
       CASE WHEN i.table_schema IS NULL THEN 'NO existe'
            WHEN i.table_schema = 'main' THEN 'existe (tabla CDM del ETL)'
            ELSE 'existe (creada por nosotros en este lab)' END       AS estado
FROM (VALUES ('drug_era'), ('dose_era'), ('condition_era')) AS t(tabla_buscada)
LEFT JOIN information_schema.tables i ON lower(i.table_name) = t.tabla_buscada
ORDER BY 1, 2;


-- >>> CONSULTA 4.6 | [CREA results.drug_era] (Opcional) ¿Y la DRUG_ERA completa para TODOS los ingredientes, con el mismo método?
-- Mismo algoritmo (fin imputado, tramos, ventana de 30 días) sobre todas
-- las exposiciones subidas a su ingrediente.
CREATE OR REPLACE TABLE results.drug_era AS
WITH expo AS (
    SELECT DISTINCT d.person_id, ca.ancestor_concept_id AS ingrediente_id,
           d.drug_exposure_start_date AS inicio,
           d.drug_exposure_start_date +
             CAST(CASE WHEN d.verbatim_end_date IS NULL THEN p.dias_si_falta_fin + 1
                       ELSE greatest(date_diff('day', d.drug_exposure_start_date, d.drug_exposure_end_date), 1)
                  END - 1 AS INTEGER) AS fin
    FROM drug_exposure d
    JOIN results.parametros p ON TRUE
    JOIN concept_ancestor ca ON ca.descendant_concept_id = d.drug_concept_id
    JOIN concept i ON i.concept_id = ca.ancestor_concept_id
                  AND i.concept_class_id = 'Ingredient' AND i.standard_concept = 'S'
),
t1 AS (  -- tramos sin huecos
    SELECT *, sum(CASE WHEN mp IS NULL OR inicio > mp + 1 THEN 1 ELSE 0 END)
              OVER (PARTITION BY person_id, ingrediente_id ORDER BY inicio, fin ROWS UNBOUNDED PRECEDING) AS tramo
    FROM (SELECT *, max(fin) OVER (PARTITION BY person_id, ingrediente_id ORDER BY inicio, fin
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS mp FROM expo)
),
tramos AS (
    SELECT person_id, ingrediente_id, tramo, min(inicio) AS inicio, max(fin) AS fin, count(*) AS n_expo
    FROM t1 GROUP BY ALL
),
t2 AS (  -- eras con ventana de persistencia
    SELECT *, sum(CASE WHEN mp IS NULL OR inicio > mp + v THEN 1 ELSE 0 END)
              OVER (PARTITION BY person_id, ingrediente_id ORDER BY inicio ROWS UNBOUNDED PRECEDING) AS era
    FROM (SELECT tr.*, p.ventana_persistencia_dias AS v,
                 max(tr.fin) OVER (PARTITION BY tr.person_id, tr.ingrediente_id ORDER BY tr.inicio
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS mp
          FROM tramos tr, results.parametros p)
)
SELECT row_number() OVER (ORDER BY person_id, ingrediente_id, min(inicio)) AS drug_era_id,
       person_id,
       ingrediente_id                       AS drug_concept_id,
       min(inicio)                          AS drug_era_start_date,
       max(fin)                             AS drug_era_end_date,
       sum(n_expo)::INTEGER                 AS drug_exposure_count,
       (date_diff('day', min(inicio), max(fin)) + 1 - sum(date_diff('day', inicio, fin) + 1))::INTEGER AS gap_days
FROM t2
GROUP BY person_id, ingrediente_id, era;
SELECT count(*) AS n_eras, count(DISTINCT person_id) AS n_personas,
       count(DISTINCT drug_concept_id) AS n_ingredientes
FROM results.drug_era;


-- >>> CONSULTA 4.7 | ¿Coincide la era "a mano" del ingrediente (4.3) con la de la DRUG_ERA completa (4.6)?
SELECT c.concept_name                                           AS ingrediente,
       (SELECT count(*) FROM results.drug_era_ingrediente)      AS eras_4_3,
       count(*)                                                 AS eras_4_6,
       (SELECT count(DISTINCT person_id) FROM results.drug_era_ingrediente) AS personas_4_3,
       count(DISTINCT e.person_id)                              AS personas_4_6
FROM results.drug_era e
JOIN results.parametros p ON e.drug_concept_id = p.ingrediente_id
JOIN concept c ON c.concept_id = e.drug_concept_id
GROUP BY 1;


-- =============================================================================
-- ACTIVIDAD 5 — Adherencia: PDC (y MPR) a 1 año desde la primera exposición
-- =============================================================================

-- >>> CONSULTA 5.1 | [CREA results.pdc_ingrediente] ¿Qué PDC y MPR tiene cada paciente en su primer año de tratamiento?
-- Fecha índice = primera exposición al ingrediente.
-- Ventana = [índice, índice + 364], recortada al fin del observation_period.
-- PDC = días DISTINTOS cubiertos / días de la ventana  (máximo 1)
-- MPR = suma de días suministrados (recetas iniciadas en la ventana) / días
--       de la ventana  (puede ser > 1 si hay solapes o la última receta
--       se pasa del final de la ventana)
-- elegible     : ventana >= 91 días (hay seguimiento suficiente)
-- elegible_pqa : además >= 2 recetas en fechas distintas (criterio PQA).
--   OJO: Synthea a veces emite UNA receta de ~1 año (371 días); con el
--   criterio PQA esos pacientes quedarían fuera aunque estén cubiertos.
CREATE OR REPLACE TABLE results.pdc_ingrediente AS
WITH indice AS (
    SELECT person_id, min(inicio) AS fecha_indice
    FROM results.exposicion_ingrediente GROUP BY person_id
),
ventana AS (
    SELECT i.person_id, i.fecha_indice,
           least(i.fecha_indice + (p.seguimiento_pdc_dias - 1),
                 max(op.observation_period_end_date)) AS fin_ventana
    FROM indice i
    JOIN results.parametros p ON TRUE
    JOIN observation_period op ON op.person_id = i.person_id
    GROUP BY i.person_id, i.fecha_indice, p.seguimiento_pdc_dias
),
cubiertos AS (
    SELECT v.person_id,
           sum(greatest(0, date_diff('day', greatest(c.inicio, v.fecha_indice),
                                            least(c.fin, v.fin_ventana)) + 1)) AS dias_cubiertos
    FROM ventana v JOIN results.cobertura_ingrediente c ON c.person_id = v.person_id
    GROUP BY v.person_id
),
suministro AS (
    SELECT v.person_id,
           sum(x.dias)                    AS dias_suministrados,
           count(*)                       AS n_recetas,
           count(DISTINCT x.inicio)       AS n_fechas_distintas
    FROM ventana v JOIN results.exposicion_ingrediente x
      ON x.person_id = v.person_id AND x.inicio BETWEEN v.fecha_indice AND v.fin_ventana
    GROUP BY v.person_id
)
SELECT v.person_id, v.fecha_indice, v.fin_ventana,
       date_diff('day', v.fecha_indice, v.fin_ventana) + 1                     AS dias_ventana,
       COALESCE(c.dias_cubiertos, 0)                                           AS dias_cubiertos,
       s.dias_suministrados, s.n_recetas, s.n_fechas_distintas,
       round(COALESCE(c.dias_cubiertos, 0) / (date_diff('day', v.fecha_indice, v.fin_ventana) + 1), 4) AS pdc,
       round(s.dias_suministrados / (date_diff('day', v.fecha_indice, v.fin_ventana) + 1), 4)          AS mpr,
       (date_diff('day', v.fecha_indice, v.fin_ventana) + 1 >= 91)                                     AS elegible,
       (date_diff('day', v.fecha_indice, v.fin_ventana) + 1 >= 91 AND s.n_fechas_distintas >= 2)        AS elegible_pqa
FROM ventana v
LEFT JOIN cubiertos c  ON c.person_id = v.person_id
LEFT JOIN suministro s ON s.person_id = v.person_id;
SELECT count(*) AS n_personas, count(*) FILTER (WHERE elegible) AS n_elegibles,
       count(*) FILTER (WHERE elegible_pqa) AS n_elegibles_pqa
FROM results.pdc_ingrediente;


-- >>> CONSULTA 5.2 | ¿Cómo se distribuye el PDC entre los pacientes elegibles y qué % es adherente (PDC >= 0.8)?
-- Dos poblaciones: ventana >= 91 días, y además criterio PQA (>= 2 recetas).
SELECT c.concept_name                                       AS ingrediente,
       g.poblacion,
       count(DISTINCT x.person_id)                          AS n_personas,
       round(quantile_cont(x.pdc, 0.10), 3)                 AS pdc_p10,
       round(quantile_cont(x.pdc, 0.25), 3)                 AS pdc_p25,
       round(median(x.pdc), 3)                              AS pdc_mediana,
       round(avg(x.pdc), 3)                                 AS pdc_media,
       round(100.0 * count(DISTINCT x.person_id) FILTER (WHERE x.pdc >= 0.8)
             / count(DISTINCT x.person_id), 1)              AS pct_adherentes_pdc_080
FROM results.pdc_ingrediente x
JOIN (VALUES ('a) ventana >= 91 días', FALSE), ('b) + criterio PQA (>= 2 recetas)', TRUE)) AS g(poblacion, pqa)
  ON x.elegible AND (NOT g.pqa OR x.elegible_pqa)
JOIN results.parametros p ON TRUE
JOIN concept c ON c.concept_id = p.ingrediente_id
GROUP BY 1, 2
ORDER BY 2;


-- >>> CONSULTA 5.3 | ¿En cuántos pacientes el MPR supera 1 (y el PDC nunca)? ¿Por qué?
-- El MPR suma días de recetas: si se solapan o la última receta se sale
-- de la ventana, pasa de 1. El PDC cuenta cada día una sola vez.
SELECT count(DISTINCT person_id)                                   AS n_personas_elegibles,
       count(DISTINCT person_id) FILTER (WHERE mpr > 1)            AS n_mpr_mayor_1,
       round(max(mpr), 3)                                          AS mpr_maximo,
       round(max(pdc), 3)                                          AS pdc_maximo,
       round(avg(mpr), 3)                                          AS mpr_media,
       round(avg(pdc), 3)                                          AS pdc_media,
       round(100.0 * count(DISTINCT person_id) FILTER (WHERE least(mpr, 1) >= 0.8)
             / count(DISTINCT person_id), 1)                       AS pct_adherentes_mpr_080
FROM results.pdc_ingrediente
WHERE elegible;


-- >>> CONSULTA 5.4 | ¿Cuántos pacientes quedan fuera de la elegibilidad y por qué?
SELECT CASE WHEN dias_ventana < 91 THEN 'a) ventana < 91 días (poco seguimiento)'
            WHEN n_fechas_distintas < 2 THEN 'b) elegible, pero solo 1 receta en el año (fuera en PQA)'
            ELSE 'c) elegible también con criterio PQA' END AS motivo,
       round(avg(pdc), 3)                              AS pdc_media,
       count(DISTINCT person_id)                       AS n_personas
FROM results.pdc_ingrediente
GROUP BY 1 ORDER BY 1;


-- =============================================================================
-- ACTIVIDAD 6 — Caracterizar MEASUREMENT
-- =============================================================================

-- >>> CONSULTA 6.1 | ¿Cuáles son los 15 analitos con más mediciones (y cuántos pacientes tienen cada uno)?
SELECT m.measurement_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)') AS analito,
       count(*)                                         AS n_mediciones,
       count(DISTINCT m.person_id)                      AS n_personas,
       count(DISTINCT m.unit_concept_id)                AS n_unidades
FROM measurement m
LEFT JOIN concept c ON c.concept_id = m.measurement_concept_id
WHERE m.measurement_concept_id <> 0
GROUP BY 1, 2
ORDER BY n_mediciones DESC
LIMIT 15;


-- >>> CONSULTA 6.2 | ¿En qué unidades viene la glucosa (o el analito de parámetros)?
SELECT ca.concept_name                                   AS analito,
       m.unit_source_value                               AS unidad_fuente,
       m.unit_concept_id,
       COALESCE(cu.concept_name, '(no está en CONCEPT)') AS unidad,
       count(*)                                          AS n_mediciones,
       count(DISTINCT m.person_id)                       AS n_personas
FROM measurement m
JOIN results.parametros p ON m.measurement_concept_id = p.glucosa_id
JOIN concept ca ON ca.concept_id = m.measurement_concept_id
LEFT JOIN concept cu ON cu.concept_id = m.unit_concept_id
GROUP BY 1, 2, 3, 4
ORDER BY n_mediciones DESC;


-- >>> CONSULTA 6.3 | ¿Qué analitos aparecen con MÁS DE UNA unidad?
SELECT m.measurement_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')          AS analito,
       count(DISTINCT m.unit_source_value)                       AS n_unidades_fuente,
       string_agg(DISTINCT m.unit_source_value, ', ')            AS unidades_fuente,
       count(*)                                                  AS n_mediciones
FROM measurement m
LEFT JOIN concept c ON c.concept_id = m.measurement_concept_id
GROUP BY 1, 2
HAVING count(DISTINCT m.unit_source_value) > 1
ORDER BY n_mediciones DESC;


-- >>> CONSULTA 6.4 | ¿Qué % de mediciones no tiene valor numérico, tiene operador (<, >) o tiene unit_concept_id = 0?
SELECT count(*)                                                                      AS n_mediciones,
       round(100.0 * count(*) FILTER (WHERE value_as_number IS NULL) / count(*), 2)  AS pct_valor_nulo,
       round(100.0 * count(*) FILTER (WHERE operator_concept_id IS NOT NULL) / count(*), 2) AS pct_con_operador,
       round(100.0 * count(*) FILTER (WHERE value_as_concept_id IS NOT NULL) / count(*), 2) AS pct_valor_concepto,
       round(100.0 * count(*) FILTER (WHERE unit_concept_id = 0) / count(*), 2)      AS pct_unidad_0,
       round(100.0 * count(*) FILTER (WHERE measurement_concept_id = 0) / count(*), 2) AS pct_concepto_0
FROM measurement;


-- >>> CONSULTA 6.5 | ¿Qué unidades fuente se quedaron sin unit_concept_id (las 10 más frecuentes)?
-- Pista: muchas son unidades "anotadas" de UCUM como {score} o {nominal},
-- que no existen tal cual como concepto estándar.
SELECT m.unit_source_value                               AS unidad_fuente,
       count(DISTINCT m.measurement_concept_id)          AS n_analitos,
       any_value(COALESCE(c.concept_name, '(sin concepto)')) AS ejemplo_analito,
       count(*)                                          AS n_mediciones
FROM measurement m
LEFT JOIN concept c ON c.concept_id = m.measurement_concept_id
WHERE m.unit_concept_id = 0
GROUP BY 1
ORDER BY n_mediciones DESC
LIMIT 10;


-- =============================================================================
-- ACTIVIDAD 7 — Normalizar unidades
--   * caso REAL : temperatura corporal en Cel y [degF]  -> °C = (°F - 32) x 5/9
--   * caso SIMULADO: glucosa mg/dL <-> mmol/L (factor 18.016)
-- =============================================================================

-- >>> CONSULTA 7.0 | Antes de convertir: ¿los valores de cada unidad tienen la magnitud que esperas de esa unidad?
-- Mira mínimo/mediana/máximo por unidad. Tres situaciones distintas:
--   * unidad realmente distinta (Cel vs [degF]) -> se convierte
--   * misma magnitud con etiqueta distinta (U/L vs [iU]/L; pg/mL vs ng/L)
--     -> equivalentes, solo se unifica la etiqueta
--   * etiqueta incoherente con los valores (p. ej. globulina "g/L" con
--     valores de 2-3.5, que son g/dL) o dos magnitudes distintas bajo el
--     mismo código (RDW en % y en fL) -> NO convertir a ciegas: se marca
SELECT m.measurement_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)')  AS analito,
       m.unit_source_value                               AS unidad_fuente,
       COALESCE(cu.concept_name, '(unit_concept_id 0)')  AS unidad,
       count(*)                                          AS n_mediciones,
       round(min(m.value_as_number), 2)                  AS minimo,
       round(median(m.value_as_number), 2)               AS mediana,
       round(max(m.value_as_number), 2)                  AS maximo
FROM measurement m
LEFT JOIN concept c  ON c.concept_id = m.measurement_concept_id
LEFT JOIN concept cu ON cu.concept_id = m.unit_concept_id
WHERE m.measurement_concept_id IN (
        SELECT measurement_concept_id FROM measurement
        WHERE measurement_concept_id <> 0
        GROUP BY 1 HAVING count(DISTINCT unit_source_value) > 1)
GROUP BY 1, 2, 3, 4
ORDER BY 2, 5 DESC;


-- >>> CONSULTA 7.1 | [CREA results.glucosa_simulada] Simulamos que el 30 % de las glucosas llegó en mmol/L. ¿Cuántas quedaron así?
-- Synthea da TODA la glucosa en mg/dL, así que "estropeamos" a propósito
-- una fracción fija (elegida con una fórmula determinista sobre
-- measurement_id, así siempre salen las mismas filas):
--   valor_mmol = valor_mg / 18.016
CREATE OR REPLACE TABLE results.glucosa_simulada AS
SELECT m.measurement_id, m.person_id, m.measurement_concept_id, m.measurement_date,
       CASE WHEN simulada THEN round(m.value_as_number / p.factor_glucosa, 2)
            ELSE m.value_as_number END                                   AS value_as_number,
       CASE WHEN simulada THEN 'mmol/L' ELSE m.unit_source_value END     AS unit_source_value,
       CASE WHEN simulada THEN (SELECT min(concept_id) FROM concept
                                 WHERE vocabulary_id = 'UCUM' AND concept_code = 'mmol/L')
            ELSE m.unit_concept_id END                                   AS unit_concept_id
FROM (SELECT *, ((measurement_id::BIGINT * 2654435761) % 1000) <
                (SELECT fraccion_simulada * 1000 FROM results.parametros) AS simulada
      FROM measurement) m
JOIN results.parametros p ON m.measurement_concept_id = p.glucosa_id;
SELECT g.unit_source_value AS unidad_fuente,
       COALESCE(cu.concept_name, '(no está en CONCEPT)') AS unidad,
       count(*) AS n_mediciones,
       round(avg(g.value_as_number), 2) AS media,
       round(min(g.value_as_number), 2) AS minimo,
       round(max(g.value_as_number), 2) AS maximo
FROM results.glucosa_simulada g
LEFT JOIN concept cu ON cu.concept_id = g.unit_concept_id
GROUP BY 1, 2 ORDER BY 3 DESC;


-- >>> CONSULTA 7.2 | [CREA results.measurement_normalizada] ¿Cuántas filas hay que convertir y cómo quedan (glucosa simulada + temperatura real)?
-- Reglas:  glucosa  mmol/L -> mg/dL : valor x 18.016
--          temperatura [degF] -> Cel : (valor - 32) x 5/9
-- Guardamos SIEMPRE el valor y la unidad originales (trazabilidad).
CREATE OR REPLACE TABLE results.measurement_normalizada AS
SELECT g.measurement_id, g.person_id, g.measurement_concept_id, g.measurement_date,
       'glucosa (simulada)'                                   AS caso,
       g.value_as_number                                      AS value_original,
       g.unit_source_value                                    AS unit_original,
       g.unit_concept_id                                      AS unit_concept_id_original,
       CASE WHEN g.unit_source_value = 'mmol/L' THEN round(g.value_as_number * p.factor_glucosa, 1)
            ELSE g.value_as_number END                        AS value_as_number,
       'mg/dL'                                                AS unit_source_value,
       (SELECT min(concept_id) FROM concept
         WHERE vocabulary_id = 'UCUM' AND concept_code = 'mg/dL') AS unit_concept_id,
       (g.unit_source_value = 'mmol/L')                       AS convertido
FROM results.glucosa_simulada g, results.parametros p
UNION ALL
SELECT m.measurement_id, m.person_id, m.measurement_concept_id, m.measurement_date,
       'temperatura (real)',
       m.value_as_number, m.unit_source_value, m.unit_concept_id,
       CASE WHEN m.unit_source_value = '[degF]' THEN round((m.value_as_number - 32) * 5 / 9, 1)
            ELSE m.value_as_number END,
       'Cel',
       (SELECT min(concept_id) FROM concept WHERE vocabulary_id = 'UCUM' AND concept_code = 'Cel'),
       (m.unit_source_value = '[degF]')
FROM measurement m
JOIN concept c ON c.concept_id = m.measurement_concept_id
WHERE c.vocabulary_id = 'LOINC' AND c.concept_code = '8310-5';   -- Body temperature
SELECT n.caso, c.concept_name AS analito, n.unit_original, n.convertido,
       count(*)                                  AS n_mediciones,
       count(DISTINCT n.person_id)               AS n_personas,
       round(avg(n.value_original), 2)           AS media_original,
       round(avg(n.value_as_number), 2)          AS media_normalizada,
       any_value(n.unit_source_value)            AS unidad_final
FROM results.measurement_normalizada n
JOIN concept c ON c.concept_id = n.measurement_concept_id
GROUP BY 1, 2, 3, 4 ORDER BY 1, 4;


-- >>> CONSULTA 7.3 | ¿Recuperamos los valores reales? (diferencia normalizado - original de MEASUREMENT)
-- Comprobación: tras ida y vuelta la diferencia debe ser solo de redondeo.
-- (Solo tiene sentido para la glucosa simulada: allí conocemos el valor real.)
SELECT n.convertido,
       count(*)                                                   AS n_mediciones,
       round(max(abs(n.value_as_number - m.value_as_number)), 3)  AS max_diferencia_abs,
       round(avg(abs(n.value_as_number - m.value_as_number)), 4)  AS media_diferencia_abs
FROM results.measurement_normalizada n
JOIN measurement m ON m.measurement_id = n.measurement_id
WHERE n.caso = 'glucosa (simulada)'
GROUP BY 1 ORDER BY 1;


-- =============================================================================
-- ACTIVIDAD 8 — Rangos plausibles (fuentes citables) y valores centinela
-- =============================================================================

-- >>> CONSULTA 8.1 | [CREA results.rangos_plausibles] ¿Qué rangos plausibles usaremos y de dónde salen?
-- Fuente principal: OHDSI Data Quality Dashboard v1.4.1, fichero
--   OMOP_CDMv5.3.1_Concept_Level.csv (plausibleValueLow/High por concepto+unidad).
--   https://github.com/OHDSI/DataQualityDashboard/blob/v1.4.1/inst/csv/OMOP_CDMv5.3.1_Concept_Level.csv
-- Fuente alternativa (vitales en UCI): MIMIC-IV, mimic-code vitalsign.sql
--   (FC > 0 y < 300; PAS > 0 y < 400)
--   https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts/measurement/vitalsign.sql
CREATE OR REPLACE TABLE results.rangos_plausibles AS
SELECT c.concept_id AS measurement_concept_id, r.loinc, r.unidad, r.bajo, r.alto,
       r.bajo_alt, r.alto_alt, r.fuente
FROM (VALUES
    ('29463-7', 'kg',     2.0,  500.0, NULL, NULL,  'DQD v1.4.1 (kg)'),
    ('8867-4',  '/min',  10.0,  500.0, 0.0,  300.0, 'DQD v1.4.1; alt. MIMIC-IV (0,300)'),
    ('8480-6',  'mm[Hg]',10.0,  250.0, 0.0,  400.0, 'DQD v1.4.1; alt. MIMIC-IV (0,400)'),
    ('39156-5', 'kg/m2', 16.0,  100.0, NULL, NULL,  'DQD v1.4.1 (extra: umbral pensado en adultos)')
) AS r(loinc, unidad, bajo, alto, bajo_alt, alto_alt, fuente)
JOIN concept c ON c.vocabulary_id = 'LOINC' AND c.concept_code = r.loinc;
SELECT r.measurement_concept_id, c.concept_name AS analito, r.unidad, r.bajo, r.alto,
       r.bajo_alt, r.alto_alt, r.fuente
FROM results.rangos_plausibles r JOIN concept c ON c.concept_id = r.measurement_concept_id
ORDER BY 2;


-- >>> CONSULTA 8.2 | ¿Cuántas mediciones (y personas) caen fuera del rango, separando niños y adultos?
SELECT c.concept_name                                                  AS analito,
       CASE WHEN year(m.measurement_date) - pe.year_of_birth < 18 THEN '< 18 años' ELSE '>= 18 años' END AS grupo_edad,
       count(*)                                                        AS n_mediciones,
       count(*) FILTER (WHERE m.value_as_number < r.bajo)              AS n_bajo,
       count(*) FILTER (WHERE m.value_as_number > r.alto)              AS n_alto,
       round(100.0 * count(*) FILTER (WHERE m.value_as_number < r.bajo OR m.value_as_number > r.alto) / count(*), 2) AS pct_fuera,
       count(DISTINCT m.person_id) FILTER (WHERE m.value_as_number < r.bajo OR m.value_as_number > r.alto) AS n_personas_fuera,
       count(*) FILTER (WHERE m.value_as_number <= r.bajo_alt OR m.value_as_number >= r.alto_alt) AS n_fuera_alt
FROM measurement m
JOIN results.rangos_plausibles r ON r.measurement_concept_id = m.measurement_concept_id
JOIN concept c  ON c.concept_id = m.measurement_concept_id
JOIN person pe  ON pe.person_id = m.person_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- >>> CONSULTA 8.3 | ¿Hay valores "centinela" (exactamente repetidos e imposibles, p. ej. 0, 999, 9999, -1)?
-- Miramos los 5 valores exactos más repetidos por analito y si están fuera
-- de rango. Un valor imposible que se repite mucho suele ser un código de
-- "sin dato" del sistema origen, no una medición real.
WITH frec AS (
    SELECT m.measurement_concept_id, m.value_as_number AS valor, count(*) AS n,
           sum(count(*)) OVER (PARTITION BY m.measurement_concept_id) AS total,
           row_number() OVER (PARTITION BY m.measurement_concept_id ORDER BY count(*) DESC) AS orden
    FROM measurement m
    JOIN results.rangos_plausibles r ON r.measurement_concept_id = m.measurement_concept_id
    GROUP BY 1, 2
)
SELECT c.concept_name AS analito, f.orden, f.valor, f.n AS n_repeticiones,
       round(100.0 * f.n / f.total, 2) AS pct_del_analito,
       (f.valor < r.bajo OR f.valor > r.alto)  AS fuera_de_rango,
       (f.valor IN (0, -1, 999, 9999, 99999))  AS parece_centinela
FROM frec f
JOIN results.rangos_plausibles r ON r.measurement_concept_id = f.measurement_concept_id
JOIN concept c ON c.concept_id = f.measurement_concept_id
WHERE f.orden <= 5
ORDER BY 1, 2;


-- >>> CONSULTA 8.4 | [CREA results.measurement_plausibilidad] Decisión: MARCAR (no borrar ni poner NULL). ¿Cuántas quedan marcadas?
-- Conservamos el dato original y añadimos una bandera; cada análisis
-- decide si excluir las marcadas. Borrar o poner NULL pierde trazabilidad.
CREATE OR REPLACE TABLE results.measurement_plausibilidad AS
SELECT m.measurement_id, m.person_id, m.measurement_concept_id, m.measurement_date,
       m.value_as_number,
       (m.value_as_number < r.bajo OR m.value_as_number > r.alto)                  AS fuera_rango,
       (m.value_as_number IN (0, -1, 999, 9999, 99999))                           AS posible_centinela,
       (year(m.measurement_date) - pe.year_of_birth < 18)                         AS es_menor
FROM measurement m
JOIN results.rangos_plausibles r ON r.measurement_concept_id = m.measurement_concept_id
JOIN person pe ON pe.person_id = m.person_id;
SELECT c.concept_name AS analito,
       count(*) AS n_mediciones,
       count(*) FILTER (WHERE fuera_rango) AS n_marcadas_fuera_rango,
       count(*) FILTER (WHERE posible_centinela) AS n_posible_centinela,
       count(*) FILTER (WHERE fuera_rango AND NOT es_menor) AS n_marcadas_adultos
FROM results.measurement_plausibilidad x JOIN concept c ON c.concept_id = x.measurement_concept_id
GROUP BY 1 ORDER BY 1;


-- =============================================================================
-- ACTIVIDAD 9 — ¿MEASUREMENT u OBSERVATION? (convenciones THEMIS)
-- =============================================================================

-- >>> CONSULTA 9.1 | ¿De qué DOMINIO son los conceptos que acabaron en cada tabla clínica?
-- THEMIS: en MEASUREMENT solo van registros cuyo concepto es del dominio
-- 'Measurement' (https://ohdsi.github.io/Themis/records_with_values.html).
-- Lo mismo vale para cada tabla con su dominio.
SELECT 'measurement' AS tabla, COALESCE(c.domain_id, '(concepto 0)') AS dominio_concepto,
       count(*) AS n_registros, count(DISTINCT x.person_id) AS n_personas
FROM measurement x LEFT JOIN concept c ON c.concept_id = x.measurement_concept_id AND x.measurement_concept_id <> 0
GROUP BY 1, 2
UNION ALL
SELECT 'condition_occurrence', COALESCE(c.domain_id, '(concepto 0)'), count(*), count(DISTINCT x.person_id)
FROM condition_occurrence x LEFT JOIN concept c ON c.concept_id = x.condition_concept_id AND x.condition_concept_id <> 0
GROUP BY 1, 2
UNION ALL
SELECT 'drug_exposure', COALESCE(c.domain_id, '(concepto 0)'), count(*), count(DISTINCT x.person_id)
FROM drug_exposure x LEFT JOIN concept c ON c.concept_id = x.drug_concept_id AND x.drug_concept_id <> 0
GROUP BY 1, 2
ORDER BY 1, 3 DESC;


-- >>> CONSULTA 9.2 | ¿Dónde quedaron el PESO, el TABAQUISMO y el "IMC 30+ obesidad" en nuestra base?
-- Buscamos por nombre en las tablas clínicas y mostramos el dominio del
-- concepto (dónde DEBERÍA ir según OMOP).
SELECT 'measurement' AS tabla_actual, c.concept_id, c.concept_name, c.domain_id AS dominio_concepto,
       count(*) AS n_registros, count(DISTINCT x.person_id) AS n_personas
FROM measurement x JOIN concept c ON c.concept_id = x.measurement_concept_id
WHERE c.concept_name ILIKE 'Body weight' OR c.concept_name ILIKE '%smok%' OR c.concept_name ILIKE '%tobacco%'
   OR c.concept_name ILIKE 'Body mass index%'
GROUP BY 1, 2, 3, 4
UNION ALL
SELECT 'condition_occurrence', c.concept_id, c.concept_name, c.domain_id, count(*), count(DISTINCT x.person_id)
FROM condition_occurrence x JOIN concept c ON c.concept_id = x.condition_concept_id
WHERE c.concept_name ILIKE '%smok%' OR c.concept_name ILIKE '%tobacco%' OR c.concept_name ILIKE 'Body mass index%'
GROUP BY 1, 2, 3, 4
UNION ALL
-- Además, por CÓDIGO FUENTE: "Smokes tobacco daily" (SNOMED 449868002) puede
-- haberse mapeado a un concepto con otro nombre (o a 0) si en tu ATHENA no es estándar.
SELECT 'condition_occurrence (código fuente 449868002)', x.condition_concept_id,
       COALESCE(c.concept_name, '(no está en CONCEPT)'), COALESCE(c.domain_id, '-'),
       count(*), count(DISTINCT x.person_id)
FROM condition_occurrence x LEFT JOIN concept c ON c.concept_id = x.condition_concept_id
WHERE x.condition_source_value = '449868002'
GROUP BY 1, 2, 3, 4
ORDER BY 1, 5 DESC;


-- >>> CONSULTA 9.3 | ¿Qué concepto (y dominio) tendría "Tobacco smoking status" (LOINC 72166-2) y sus respuestas?
-- En observations.csv es TYPE='text' (CATEGORY social-history): convertir.py
-- NO lo cargó (solo cargamos laboratorio y vitales numéricos). Su sitio
-- sería OBSERVATION, con la respuesta en value_as_concept_id.
SELECT c.concept_id, c.concept_name, c.vocabulary_id, c.concept_code, c.domain_id,
       COALESCE(c.standard_concept, '-') AS standard_concept
FROM concept c
WHERE (c.vocabulary_id = 'LOINC'  AND c.concept_code = '72166-2')
   OR (c.vocabulary_id = 'SNOMED' AND c.concept_code IN ('266919005', '8517006', '449868002'))
ORDER BY c.vocabulary_id, c.concept_code;


-- >>> CONSULTA 9.4 | En el CSV ORIGINAL de Synthea, ¿cuántas respuestas de tabaquismo se perdieron al no tener tabla OBSERVATION?
-- Lee directamente observations.csv ({{SYNTHEA_CSV}} lo sustituye el script
-- correr_farmacoepi.py por tu carpeta de Synthea).
SELECT o.DESCRIPTION                     AS pregunta,
       o.VALUE                           AS respuesta,
       count(*)                          AS n_registros,
       count(DISTINCT o.PATIENT)         AS n_pacientes_synthea
FROM read_csv('{{SYNTHEA_CSV}}/observations.csv', header = true, all_varchar = true) o
WHERE o.CODE = '72166-2'
GROUP BY 1, 2
ORDER BY n_registros DESC;


-- =============================================================================
-- ACTIVIDAD 10 — Fecha índice y valor basal más cercano (±90 días)
-- =============================================================================

-- >>> CONSULTA 10.1 | [CREA results.indice_basal] Para cada paciente: fecha índice (1.ª exposición al ingrediente) y la PAS más cercana en ±90 días
-- Dos versiones de "basal":
--   * ±90: la medición más cercana antes O después (desempate: la anterior)
--   * pre: solo antes o el mismo día (-90..0), la definición más estricta
-- También marcamos si la fecha índice cae dentro del observation_period
-- (THEMIS: un evento fuera del periodo no puede ser fecha índice).
CREATE OR REPLACE TABLE results.indice_basal AS
WITH indice AS (
    SELECT person_id, min(inicio) AS fecha_indice FROM results.exposicion_ingrediente GROUP BY 1
),
cand AS (
    SELECT i.person_id, i.fecha_indice, m.value_as_number,
           date_diff('day', i.fecha_indice, m.measurement_date) AS dif
    FROM indice i
    JOIN results.parametros p ON TRUE
    JOIN measurement m ON m.person_id = i.person_id
                      AND m.measurement_concept_id = p.analito_basal_id
                      AND abs(date_diff('day', i.fecha_indice, m.measurement_date)) <= p.ventana_basal_dias
),
mejor_pm AS (
    SELECT person_id, value_as_number AS valor_pm90, dif AS dif_pm90
    FROM cand QUALIFY row_number() OVER (PARTITION BY person_id ORDER BY abs(dif), dif) = 1
),
mejor_pre AS (
    SELECT person_id, value_as_number AS valor_pre90, dif AS dif_pre90
    FROM cand WHERE dif <= 0
    QUALIFY row_number() OVER (PARTITION BY person_id ORDER BY dif DESC) = 1
)
SELECT i.person_id, i.fecha_indice,
       EXISTS (SELECT 1 FROM observation_period op WHERE op.person_id = i.person_id
                 AND i.fecha_indice BETWEEN op.observation_period_start_date AND op.observation_period_end_date) AS indice_en_periodo,
       a.valor_pm90, a.dif_pm90, b.valor_pre90, b.dif_pre90
FROM indice i
LEFT JOIN mejor_pm a  ON a.person_id = i.person_id
LEFT JOIN mejor_pre b ON b.person_id = i.person_id;
SELECT count(*) AS n_personas_con_indice FROM results.indice_basal;


-- >>> CONSULTA 10.2 | ¿Cuántos pacientes tienen valor basal (±90 y solo previo) y cómo es?
SELECT ci.concept_name                                                     AS ingrediente,
       cb.concept_name                                                     AS analito_basal,
       count(DISTINCT x.person_id)                                         AS n_personas,
       count(DISTINCT x.person_id) FILTER (WHERE x.indice_en_periodo)      AS n_indice_en_periodo,
       count(DISTINCT x.person_id) FILTER (WHERE x.valor_pm90 IS NOT NULL) AS n_con_basal_pm90,
       round(100.0 * count(DISTINCT x.person_id) FILTER (WHERE x.valor_pm90 IS NOT NULL) / count(DISTINCT x.person_id), 1) AS pct_con_basal_pm90,
       count(DISTINCT x.person_id) FILTER (WHERE x.valor_pre90 IS NOT NULL) AS n_con_basal_previo,
       round(100.0 * count(DISTINCT x.person_id) FILTER (WHERE x.valor_pre90 IS NOT NULL) / count(DISTINCT x.person_id), 1) AS pct_con_basal_previo,
       round(median(x.valor_pm90), 1)                                      AS mediana_basal_pm90,
       round(median(abs(x.dif_pm90)), 1)                                   AS mediana_dias_a_indice
FROM results.indice_basal x
JOIN results.parametros p ON TRUE
JOIN concept ci ON ci.concept_id = p.ingrediente_id
JOIN concept cb ON cb.concept_id = p.analito_basal_id
GROUP BY 1, 2;


-- >>> CONSULTA 10.3 | ¿Cómo se reparte la distancia (en días) entre la fecha índice y la medición basal elegida?
SELECT CASE WHEN dif_pm90 IS NULL THEN 'z) sin basal en ±90'
            WHEN dif_pm90 < -30 THEN 'a) -90 a -31'
            WHEN dif_pm90 < 0   THEN 'b) -30 a -1'
            WHEN dif_pm90 = 0   THEN 'c) mismo día'
            WHEN dif_pm90 <= 30 THEN 'd) +1 a +30'
            ELSE 'e) +31 a +90' END        AS distancia,
       count(DISTINCT person_id)          AS n_personas
FROM results.indice_basal
GROUP BY 1 ORDER BY 1;


-- =============================================================================
-- EXTRA — CONDITION_ERA con el mismo patrón (ventana de 30 días)
-- =============================================================================

-- >>> CONSULTA 11.1 | [CREA results.condition_era] (Extra) ¿Qué eras de condición salen con la ventana de 30 días?
-- Fin de cada condición = condition_end_date o, si falta, la de inicio.
-- Solo condiciones mapeadas (condition_concept_id <> 0).
CREATE OR REPLACE TABLE results.condition_era AS
WITH occ AS (
    SELECT person_id, condition_concept_id, condition_start_date AS inicio,
           COALESCE(condition_end_date, condition_start_date) AS fin
    FROM condition_occurrence WHERE condition_concept_id <> 0
),
islas AS (
    SELECT *, sum(CASE WHEN mp IS NULL OR inicio > mp + v THEN 1 ELSE 0 END)
              OVER (PARTITION BY person_id, condition_concept_id ORDER BY inicio, fin ROWS UNBOUNDED PRECEDING) AS era
    FROM (SELECT o.*, p.ventana_persistencia_dias AS v,
                 max(fin) OVER (PARTITION BY person_id, condition_concept_id ORDER BY inicio, fin
                                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS mp
          FROM occ o, results.parametros p)
)
SELECT row_number() OVER (ORDER BY person_id, condition_concept_id, min(inicio)) AS condition_era_id,
       person_id, condition_concept_id,
       min(inicio) AS condition_era_start_date,
       max(fin)    AS condition_era_end_date,
       count(*)::INTEGER AS condition_occurrence_count
FROM islas
GROUP BY person_id, condition_concept_id, era;
SELECT count(*) AS n_eras, count(DISTINCT person_id) AS n_personas,
       (SELECT count(*) FROM condition_occurrence WHERE condition_concept_id <> 0) AS n_condiciones_origen
FROM results.condition_era;


-- >>> CONSULTA 11.2 | (Extra) ¿Qué condiciones tienen más eras por persona (episodios repetidos)?
SELECT e.condition_concept_id,
       c.concept_name                                  AS condicion,
       count(*)                                        AS n_eras,
       count(DISTINCT e.person_id)                     AS n_personas,
       round(count(*) / count(DISTINCT e.person_id), 2) AS eras_por_persona
FROM results.condition_era e
JOIN concept c ON c.concept_id = e.condition_concept_id
GROUP BY 1, 2
ORDER BY n_personas DESC
LIMIT 10;
