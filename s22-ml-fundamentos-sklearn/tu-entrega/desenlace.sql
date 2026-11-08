WITH fin AS (
  SELECT MAX(observation_period_end_date) AS fecha_fin
  FROM observation_period
),
c AS (
  SELECT co.subject_id, co.cohort_start_date, d.death_date
  FROM results.cohort co
  LEFT JOIN death d ON d.person_id = co.subject_id
  WHERE co.cohort_definition_id = 1701
)
SELECT
  (SELECT fecha_fin FROM fin) AS fin_datos,
  COUNT(*) AS total,
  SUM(CASE WHEN cohort_start_date + INTERVAL 90 DAY <= (SELECT fecha_fin FROM fin) THEN 1 ELSE 0 END) AS con_90d_seguimiento,
  SUM(CASE WHEN death_date BETWEEN cohort_start_date + INTERVAL 1 DAY
                              AND cohort_start_date + INTERVAL 90 DAY THEN 1 ELSE 0 END) AS muertes_1_90
FROM c;
