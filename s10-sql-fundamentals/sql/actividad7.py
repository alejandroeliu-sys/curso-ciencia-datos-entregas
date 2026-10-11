from pathlib import Path
import duckdb

base = Path.home() / "s10-sql-fundamentals"
con = duckdb.connect(str(base / "clinica.duckdb"))

# Correcto: una fila por encuentro.
n_correcto = con.execute(
    """
    SELECT COUNT(*)
    FROM encounters
    WHERE STOP IS NOT NULL
    """
).fetchone()[0]

promedio_correcto = con.execute(
    """
    SELECT ROUND(AVG(DATE_DIFF('hour', START, STOP)), 2)
    FROM encounters
    WHERE STOP IS NOT NULL
    """
).fetchone()[0]

# Inflado: el mismo encuentro se repite una vez por cada diagnóstico.
n_inflado = con.execute(
    """
    SELECT COUNT(*)
    FROM encounters AS e
    JOIN conditions AS c
        ON e.Id = c.ENCOUNTER
    WHERE e.STOP IS NOT NULL
    """
).fetchone()[0]

promedio_inflado = con.execute(
    """
    SELECT ROUND(AVG(DATE_DIFF('hour', e.START, e.STOP)), 2)
    FROM encounters AS e
    JOIN conditions AS c
        ON e.Id = c.ENCOUNTER
    WHERE e.STOP IS NOT NULL
    """
).fetchone()[0]

# Corregido: se agrupa a una fila por encuentro y el promedio vuelve al valor bueno.
promedio_corregido = con.execute(
    """
    SELECT ROUND(AVG(horas), 2)
    FROM (
        SELECT
            e.Id,
            MAX(DATE_DIFF('hour', e.START, e.STOP)) AS horas
        FROM encounters AS e
        LEFT JOIN conditions AS c
            ON e.Id = c.ENCOUNTER
        WHERE e.STOP IS NOT NULL
        GROUP BY e.Id
    ) AS uno_por_encuentro
    """
).fetchone()[0]

print("filas correctas:", n_correcto)
print("filas infladas:", n_inflado)
print("promedio correcto:", promedio_correcto)
print("promedio inflado:", promedio_inflado)
print("promedio corregido:", promedio_corregido)
con.close()
