from pathlib import Path
import time
import duckdb

base = Path.home() / "s10-sql-fundamentals"
con = duckdb.connect(str(base / "clinica.duckdb"))
informe = base / "sql" / "planes_actividad9.txt"
col_tipo = chr(34) + "TYPE" + chr(34)

sql = (
    "SELECT COUNT(*) AS n, "
    "ROUND(AVG(valor), 2) AS media, "
    "ROUND(MEDIAN(valor), 2) AS mediana, "
    "ROUND(QUANTILE_CONT(valor, 0.1), 2) AS p10, "
    "ROUND(QUANTILE_CONT(valor, 0.9), 2) AS p90 "
    "FROM ( "
    "SELECT TRY_CAST(VALUE AS DOUBLE) AS valor "
    "FROM observations "
    "WHERE contains(DESCRIPTION, 'Hemoglobin A1c') "
    "AND " + col_tipo + " = 'numeric' "
    ") AS mediciones "
    "WHERE valor IS NOT NULL"
)


def medir(titulo, sentencia):
    inicio = time.perf_counter()
    plan = con.execute("EXPLAIN ANALYZE " + sentencia).fetchall()
    segundos = time.perf_counter() - inicio
    texto = "\n".join(str(fila[0]) for fila in plan)
    print("")
    print(titulo)
    print("tiempo:", round(segundos, 3), "segundos")
    print(texto)
    return titulo + "\ntiempo: " + str(round(segundos, 3)) + "\n" + texto + "\n"


partes = []
partes.append(medir("1. Consulta original", sql))
con.execute(
    "CREATE INDEX IF NOT EXISTS idx_obs_desc ON observations(DESCRIPTION)"
)
partes.append(medir("2. La misma consulta, con indice", sql))
con.execute("DROP INDEX IF EXISTS idx_obs_desc")
informe.write_text("\n\n".join(partes), encoding="utf-8")
print("")
print("Planes guardados en", informe)
con.close()
