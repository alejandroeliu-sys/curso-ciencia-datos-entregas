# Paso 7: crear results.cohort, insertar la cohorte 1701 y verificar
import duckdb, os
con = duckdb.connect(os.path.expanduser('~/s12-omop-cdm-introduccion/omop.duckdb'))

con.sql("CREATE SCHEMA IF NOT EXISTS results")
con.sql("""CREATE TABLE IF NOT EXISTS results.cohort (
  cohort_definition_id INTEGER, subject_id BIGINT,
  cohort_start_date DATE, cohort_end_date DATE)""")

con.sql("DELETE FROM results.cohort WHERE cohort_definition_id = 1701")
con.sql("INSERT INTO results.cohort " + open('tu-entrega/cohorte_definicion.sql').read().rstrip().rstrip(';'))

print(con.sql("SELECT COUNT(*) AS filas FROM results.cohort WHERE cohort_definition_id = 1701").df())

# Verificación 1: ninguna fecha de fin anterior a la de inicio
print(con.sql("SELECT COUNT(*) AS fin_antes_de_inicio FROM results.cohort WHERE cohort_end_date < cohort_start_date").df())

# Verificación 2: ninguna fecha fuera del periodo de observación
print(con.sql("""SELECT COUNT(*) AS fuera_de_observacion
  FROM results.cohort c
  WHERE NOT EXISTS (SELECT 1 FROM observation_period op
                    WHERE op.person_id = c.subject_id
                      AND c.cohort_start_date >= op.observation_period_start_date
                      AND c.cohort_end_date   <= op.observation_period_end_date)""").df())
con.close()
