import duckdb

BASE = "/home/alecedillo/s12-omop-cdm-introduccion/omop_20k.duckdb"
con = duckdb.connect(BASE, read_only=True)

con.execute("""
CREATE TEMP TABLE coh AS
WITH fin AS (
  SELECT MAX(observation_period_end_date) AS fecha_fin FROM observation_period
)
SELECT co.subject_id AS person_id, co.cohort_start_date AS fecha_indice
FROM results.cohort co
CROSS JOIN fin
LEFT JOIN death d ON d.person_id = co.subject_id
WHERE co.cohort_definition_id = 1701
  AND co.cohort_start_date + INTERVAL 90 DAY <= fin.fecha_fin
  AND (d.death_date IS NULL OR d.death_date > co.cohort_start_date)
""")

def top(titulo, sql):
    print(f"\n===== {titulo} =====")
    print(con.execute(sql).df().to_string(index=False))

top("Laboratorios (MEASUREMENT)", """
SELECT m.measurement_concept_id AS concept_id, c.concept_name,
       COUNT(DISTINCT m.person_id) AS pacientes,
       ROUND(AVG(m.value_as_number), 2) AS media,
       ANY_VALUE(m.unit_source_value) AS unidad
FROM coh k
JOIN measurement m ON m.person_id = k.person_id
 AND m.measurement_date BETWEEN k.fecha_indice - INTERVAL 365 DAY
                            AND k.fecha_indice - INTERVAL 1 DAY
 AND m.value_as_number IS NOT NULL
JOIN concept c ON c.concept_id = m.measurement_concept_id
GROUP BY ALL ORDER BY pacientes DESC LIMIT 30
""")

top("Ingredientes (DRUG_EXPOSURE)", """
SELECT i.concept_id, i.concept_name,
       COUNT(DISTINCT x.person_id) AS pacientes
FROM coh k
JOIN drug_exposure x ON x.person_id = k.person_id
 AND x.drug_exposure_start_date BETWEEN k.fecha_indice - INTERVAL 365 DAY
                                    AND k.fecha_indice - INTERVAL 1 DAY
JOIN concept_ancestor ca ON ca.descendant_concept_id = x.drug_concept_id
JOIN concept i ON i.concept_id = ca.ancestor_concept_id
 AND i.concept_class_id = 'Ingredient'
GROUP BY ALL ORDER BY pacientes DESC LIMIT 30
""")

top("Diagnósticos (CONDITION_OCCURRENCE, todo el historial)", """
SELECT o.condition_concept_id AS concept_id, c.concept_name,
       COUNT(DISTINCT o.person_id) AS pacientes
FROM coh k
JOIN condition_occurrence o ON o.person_id = k.person_id
 AND o.condition_start_date <= k.fecha_indice - INTERVAL 1 DAY
JOIN concept c ON c.concept_id = o.condition_concept_id
GROUP BY ALL ORDER BY pacientes DESC LIMIT 40
""")

top("Visitas (VISIT_OCCURRENCE)", """
SELECT v.visit_concept_id AS concept_id, c.concept_name,
       COUNT(DISTINCT v.person_id) AS pacientes, COUNT(*) AS visitas
FROM coh k
JOIN visit_occurrence v ON v.person_id = k.person_id
 AND v.visit_start_date BETWEEN k.fecha_indice - INTERVAL 365 DAY
                            AND k.fecha_indice - INTERVAL 1 DAY
JOIN concept c ON c.concept_id = v.visit_concept_id
GROUP BY ALL ORDER BY pacientes DESC
""")
