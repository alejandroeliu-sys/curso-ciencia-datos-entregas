# Paso 9: tabla 1 de la cohorte 1701 + histograma del seguimiento
import duckdb, os
import matplotlib.pyplot as plt

con = duckdb.connect(os.path.expanduser('~/s12-omop-cdm-introduccion/omop.duckdb'), read_only=True)

base = """
WITH coh AS (
  SELECT c.subject_id AS person_id, c.cohort_start_date, c.cohort_end_date,
         p.gender_concept_id,
         -- edad en la FECHA ÍNDICE (no contra hoy ni contra year_of_birth a secas)
         DATE_DIFF('year',
                   MAKE_DATE(p.year_of_birth, COALESCE(p.month_of_birth, 1), COALESCE(p.day_of_birth, 1)),
                   c.cohort_start_date) AS edad
  FROM results.cohort c
  JOIN person p ON p.person_id = c.subject_id
  WHERE c.cohort_definition_id = 1701
)
"""

print("== N, edad y seguimiento ==")
print(con.sql(base + """
SELECT COUNT(*) AS n,
       MEDIAN(edad) AS edad_mediana, QUANTILE_CONT(edad, 0.25) AS edad_p25, QUANTILE_CONT(edad, 0.75) AS edad_p75,
       ROUND(AVG(edad), 1) AS edad_media,
       MEDIAN(cohort_end_date - cohort_start_date) AS seguimiento_mediano_dias
FROM coh""").df().to_string())

print("\n== Sexo ==")
print(con.sql(base + """
SELECT CASE gender_concept_id WHEN 8507 THEN 'Hombre' WHEN 8532 THEN 'Mujer' ELSE 'Otro' END AS sexo,
       COUNT(*) AS n, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM coh GROUP BY 1""").df().to_string())

print("\n== 10 comorbilidades más frecuentes en [-365, 0] ==")
print(con.sql(base + """
SELECT ct.concept_name, COUNT(DISTINCT co.person_id) AS pacientes,
       ROUND(100.0 * COUNT(DISTINCT co.person_id) / (SELECT COUNT(*) FROM coh), 1) AS pct
FROM coh
JOIN condition_occurrence co ON co.person_id = coh.person_id
     AND co.condition_start_date BETWEEN coh.cohort_start_date - INTERVAL 365 DAY AND coh.cohort_start_date
JOIN concept ct ON ct.concept_id = co.condition_concept_id
WHERE co.condition_concept_id <> 0 AND ct.concept_class_id = 'Disorder'
GROUP BY ct.concept_name
ORDER BY pacientes DESC
LIMIT 10""").df().to_string())

seg = con.sql(base + "SELECT cohort_end_date - cohort_start_date AS dias FROM coh").df()
plt.figure(figsize=(8, 4))
plt.hist(seg['dias'], bins=18, edgecolor='black')
plt.xlabel('Días de seguimiento')
plt.ylabel('Número de pacientes')
plt.title('Seguimiento en la cohorte 1701 (máximo 90 días)')
plt.tight_layout()
plt.savefig('tu-entrega/histograma_seguimiento.png', dpi=150)
print("\nHistograma guardado")
