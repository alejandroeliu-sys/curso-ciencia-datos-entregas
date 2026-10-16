-- 1. ¿Cuántas personas hay y cuántas tienen periodo de observación?
SELECT
  (SELECT COUNT(*) FROM person) AS personas,
  (SELECT COUNT(DISTINCT person_id) FROM observation_period) AS con_periodo,
  (SELECT COUNT(*) FROM observation_period) AS periodos_totales;

-- 2. Duración mediana del periodo, en días
SELECT
  MEDIAN(observation_period_end_date - observation_period_start_date) AS mediana_dias,
  MIN(observation_period_start_date) AS inicio_base,
  MAX(observation_period_end_date)   AS fin_base
FROM observation_period;

-- 3. ¿Cuántas visitas caen FUERA de cualquier periodo?
SELECT COUNT(*) AS visitas_fuera
FROM visit_occurrence v
WHERE NOT EXISTS (
  SELECT 1 FROM observation_period op
  WHERE op.person_id = v.person_id
    AND v.visit_start_date BETWEEN op.observation_period_start_date
                               AND op.observation_period_end_date
);
