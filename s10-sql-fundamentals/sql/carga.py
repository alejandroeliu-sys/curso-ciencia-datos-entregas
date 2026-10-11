from pathlib import Path
import duckdb

BASE = Path.home() / "s10-sql-fundamentals"
CSV_DIR = BASE / "synthea" / "output" / "csv"
DB_PATH = BASE / "clinica.duckdb"

ARCHIVOS = {
    "patients": "patients.csv",
    "encounters": "encounters.csv",
    "conditions": "conditions.csv",
    "medications": "medications.csv",
    "observations": "observations.csv",
}

# Estas columnas deben ser fecha, no texto.
FECHAS = {
    "patients": {"birthdate": "DATE", "deathdate": "DATE"},
    "encounters": {"start": "TIMESTAMP", "stop": "TIMESTAMP"},
    "conditions": {"start": "DATE", "stop": "DATE"},
    "medications": {"start": "TIMESTAMP", "stop": "TIMESTAMP"},
    "observations": {"date": "TIMESTAMP"},
}

OBLIGATORIAS = {
    "patients": "birthdate",
    "encounters": "start",
    "conditions": "start",
    "medications": "start",
    "observations": "date",
}


def main():
    faltan = [n for n, a in ARCHIVOS.items() if not (CSV_DIR / a).exists()]
    if faltan:
        raise SystemExit(f"Faltan CSV en {CSV_DIR}: {', '.join(faltan)}")

    con = duckdb.connect(str(DB_PATH))
    for tabla, archivo in ARCHIVOS.items():
        ruta = str(CSV_DIR / archivo)
        cols = [
            row[0]
            for row in con.execute(
                "SELECT column_name FROM (DESCRIBE SELECT * FROM read_csv(?, header=true, all_varchar=true))",
                [ruta],
            ).fetchall()
        ]
        reales = {c.lower(): c for c in cols}
        partes = []
        for logica, tipo in FECHAS[tabla].items():
            if logica not in reales:
                raise SystemExit(f"{archivo} no tiene {logica}. Tiene: {cols}")
            real = reales[logica]
            partes.append(
                f'TRY_CAST(NULLIF("{real}", \'\') AS {tipo}) AS "{real}"'
            )
        con.execute(
            f"""
            CREATE OR REPLACE TABLE {tabla} AS
            SELECT * REPLACE ({", ".join(partes)})
            FROM read_csv(?, header=true, all_varchar=true)
            """,
            [ruta],
        )
        n = con.execute(f"SELECT COUNT(*) FROM {tabla}").fetchone()[0]
        print(f"{tabla}: {n} filas")

        obligatoria = reales[OBLIGATORIAS[tabla]]
        vacias = con.execute(
            f'SELECT COUNT(*) FROM {tabla} WHERE "{obligatoria}" IS NULL'
        ).fetchone()[0]
        if vacias == n:
            print(f"  AVISO: {obligatoria} quedó toda nula. El formato de fecha no se leyó.")

    print("Base guardada en", DB_PATH)
    con.close()


if __name__ == "__main__":
    main()

