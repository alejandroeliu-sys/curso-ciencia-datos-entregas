# Actividad 9: variantes del lavado (30, 180, 365 y 730 días) a partir de cohorte_definicion.sql
import os
import duckdb
import pandas as pd

BD = os.path.expanduser('~/s12-omop-cdm-introduccion/omop.duckdb')
SQL_BASE = os.path.expanduser('~/s17-cohortes-omop-sql/tu-entrega/cohorte_definicion.sql')
TEXTO_LAVADO = 'fecha_ingreso - INTERVAL 30 DAY'

con = duckdb.connect(BD, read_only=True)
sql_base = open(SQL_BASE).read()
assert TEXTO_LAVADO in sql_base, 'No encontré la línea del lavado en el SQL'

resumen = []
cohortes = []
for dias in [30, 180, 365, 730]:
    sql = sql_base.replace(TEXTO_LAVADO, f'fecha_ingreso - INTERVAL {dias} DAY')
    coh = con.sql(sql).df()
    coh['lavado_dias'] = dias
    cohortes.append(coh)

    # Caracterización mínima: edad y sexo a la fecha índice
    personas = con.sql('SELECT person_id, year_of_birth, gender_concept_id FROM person').df()
    d = coh.merge(personas, left_on='subject_id', right_on='person_id')
    edad = pd.to_datetime(d['cohort_start_date']).dt.year - d['year_of_birth']
    resumen.append({
        'lavado_dias': dias,
        'N': len(d),
        'edad_mediana': edad.median(),
        'pct_hombres': round(100 * (d['gender_concept_id'] == 8507).mean(), 1),
        'seguimiento_mediana': (pd.to_datetime(d['cohort_end_date']) - pd.to_datetime(d['cohort_start_date'])).dt.days.median(),
    })

print(pd.DataFrame(resumen).to_string(index=False))

# Guardamos las 4 cohortes juntas para la actividad 10 (traslape)
pd.concat(cohortes).to_csv('tu-entrega/variantes_lavado.csv', index=False)
print('Guardado tu-entrega/variantes_lavado.csv')
