import duckdb

BASE = "/home/alecedillo/s12-omop-cdm-introduccion/omop_20k.duckdb"
con = duckdb.connect(BASE, read_only=True)

con.execute("""
CREATE TEMP TABLE coh AS
WITH fin AS (
  SELECT MAX(observation_period_end_date) AS fecha_fin FROM observation_period
)
SELECT co.subject_id AS person_id, co.cohort_start_date AS fecha_indice,
       CASE WHEN d.death_date BETWEEN co.cohort_start_date + INTERVAL 1 DAY
                                  AND co.cohort_start_date + INTERVAL 90 DAY
            THEN 1 ELSE 0 END AS muerte_90d
FROM results.cohort co
CROSS JOIN fin
LEFT JOIN death d ON d.person_id = co.subject_id
WHERE co.cohort_definition_id = 1701
  AND co.cohort_start_date + INTERVAL 90 DAY <= fin.fecha_fin
  AND (d.death_date IS NULL OR d.death_date > co.cohort_start_date)
""")

print(con.execute("""
SELECT COUNT(*) AS pacientes, SUM(muerte_90d) AS muertes FROM coh
""").df().to_string(index=False))

print(con.execute("""
WITH registros AS (
  SELECT c.person_id, 'diagnosticos' AS tabla,
         DATE_DIFF('day', c.fecha_indice, o.condition_start_date) AS dia
  FROM coh c JOIN condition_occurrence o ON o.person_id = c.person_id
  UNION ALL
  SELECT c.person_id, 'farmacos',
         DATE_DIFF('day', c.fecha_indice, x.drug_exposure_start_date)
  FROM coh c JOIN drug_exposure x ON x.person_id = c.person_id
  UNION ALL
  SELECT c.person_id, 'laboratorios',
         DATE_DIFF('day', c.fecha_indice, m.measurement_date)
  FROM coh c JOIN measurement m ON m.person_id = c.person_id
)
SELECT r.tabla, r.dia,
       ROUND(COUNT(*) FILTER (WHERE c.muerte_90d = 1)
             / (SELECT SUM(muerte_90d) FROM coh), 2)     AS por_fallecido,
       ROUND(COUNT(*) FILTER (WHERE c.muerte_90d = 0)
             / (SELECT SUM(1 - muerte_90d) FROM coh), 2) AS por_sobreviviente
FROM registros r JOIN coh c USING (person_id)
WHERE r.dia BETWEEN -7 AND 0
GROUP BY r.tabla, r.dia
ORDER BY r.tabla, r.dia
""").df().to_string(index=False))
