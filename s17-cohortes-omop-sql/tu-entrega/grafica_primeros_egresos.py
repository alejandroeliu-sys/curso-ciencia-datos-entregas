# Trampa 2: primeros egresos por año, antes y después del filtro de observación previa
import duckdb, os
import matplotlib.pyplot as plt

con = duckdb.connect(os.path.expanduser('~/s12-omop-cdm-introduccion/omop.duckdb'), read_only=True)


sql = open('tu-entrega/cohorte_definicion.sql').read()
ctes = sql[:sql.rfind('SELECT\n  (SELECT COUNT(*) FROM evento_inicial)')]

antes = con.sql(ctes + "SELECT YEAR(fecha_indice) AS anio, COUNT(*) AS n FROM evento_inicial GROUP BY 1 ORDER BY 1").df()
despues = con.sql(ctes + "SELECT YEAR(fecha_indice) AS anio, COUNT(*) AS n FROM observacion_previa GROUP BY 1 ORDER BY 1").df()

print(antes.to_string())

plt.figure(figsize=(10, 5))
plt.bar(antes['anio'] - 0.2, antes['n'], width=0.4, label='Antes (evento inicial)')
plt.bar(despues['anio'] + 0.2, despues['n'], width=0.4, label='Después (730 días de observación)')
plt.xlabel('Año del primer egreso')
plt.ylabel('Número de personas')
plt.title('Primeros egresos hospitalarios a los 65 años o más por año')
plt.legend()
plt.tight_layout()
plt.savefig('tu-entrega/primeros_egresos_por_anio.png', dpi=600)
print('Gráfica guardada')
