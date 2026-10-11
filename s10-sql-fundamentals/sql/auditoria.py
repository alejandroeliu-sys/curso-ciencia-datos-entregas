from pathlib import Path
import duckdb

base = Path.home() / "s10-sql-fundamentals"
con = duckdb.connect(str(base / "clinica.duckdb"))


def mostrar(titulo, sql):
    print("\n" + titulo)
    cur = con.execute(sql)
    nombres = [c[0] for c in cur.description]
    filas = cur.fetchall()
    print(" | ".join(nombres))
    if not filas:
        print("(ninguna fila)")
        return
    for fila in filas:
        print(" | ".join(str(valor) for valor in fila))


mostrar(
    "1. Ids duplicados en patients",
    """
    SELECT COUNT(*) AS ids_duplicados
    FROM (
        SELECT Id
        FROM patients
        GROUP BY Id
        HAVING COUNT(*) > 1
    ) AS repetidos
    """,
)

mostrar(
    "2. Encuentros anteriores al nacimiento",
    """
    SELECT COUNT(*) AS encuentros_antes_de_nacer
    FROM encounters AS e
    INNER JOIN patients AS p
        ON e.PATIENT = p.Id
    WHERE CAST(e.START AS DATE) < p.BIRTHDATE
    """,
)

mostrar(
    "3. Porcentaje de VALUE nulo en observations",
    """
    SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE VALUE IS NULL) AS nulos,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE VALUE IS NULL) / COUNT(*),
            2
        ) AS porcentaje_nulo
    FROM observations
    """,
)

mostrar(
    "4. Encuentros sin paciente",
    """
    SELECT COUNT(*) AS encuentros_sin_paciente
    FROM encounters AS e
    LEFT JOIN patients AS p
        ON e.PATIENT = p.Id
    WHERE p.Id IS NULL
    """,
)

con.close()
