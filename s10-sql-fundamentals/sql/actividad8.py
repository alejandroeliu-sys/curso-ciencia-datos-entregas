from pathlib import Path
import duckdb

con = duckdb.connect(str(Path.home() / "s10-sql-fundamentals" / "clinica.duckdb"))

where_filas, where_pacientes = con.execute(
    """
    SELECT COUNT(*), COUNT(DISTINCT p.Id)
    FROM patients AS p
    LEFT JOIN encounters AS e
        ON p.Id = e.PATIENT
    WHERE e.ENCOUNTERCLASS = 'emergency'
    """
).fetchone()

on_filas, on_pacientes = con.execute(
    """
    SELECT COUNT(*), COUNT(DISTINCT p.Id)
    FROM patients AS p
    LEFT JOIN encounters AS e
        ON p.Id = e.PATIENT
       AND e.ENCOUNTERCLASS = 'emergency'
    """
).fetchone()

print("WHERE filas:", where_filas)
print("WHERE pacientes:", where_pacientes)
print("ON filas:", on_filas)
print("ON pacientes:", on_pacientes)
con.close()
