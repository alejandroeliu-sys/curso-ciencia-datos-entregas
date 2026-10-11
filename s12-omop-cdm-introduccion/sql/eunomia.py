#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# Laboratorio 12 — Actividad 10: base de referencia Eunomia (GiBleed) SIN R
#                  y SIN Docker.
#
# Qué hace:
#   1) Descarga el zip oficial de OHDSI/EunomiaDatasets (CSV de un CDM ya
#      convertido por OHDSI, con su propio subconjunto de vocabulario).
#   2) Lo descomprime en ~/s12-omop-cdm-introduccion/eunomia/
#   3) Carga TODOS los CSV en ~/s12-omop-cdm-introduccion/eunomia.duckdb
#      (una tabla por CSV, nombres en minúscula).
#   4) Muestra qué vocabularios trae Eunomia.
#   5) Ejecuta las MISMAS consultas de la actividad 6 (sql/consultas_omop.sql)
#      sobre Eunomia y sobre tu omop.duckdb, y una tabla resumen comparativa.
#
# Uso (con el venv activado):
#   python sql/eunomia.py
# Solo usa la biblioteca estándar de Python + duckdb + pandas (no hace falta
# 'requests'). Se puede repetir: si el zip ya está, no lo vuelve a descargar.
#
# Variables de entorno opcionales:
#   LAB12_DIR          carpeta del lab (por defecto ~/s12-omop-cdm-introduccion)
#   EUNOMIA_DATASET    por defecto GiBleed      (otro: Synthea27Nj)
#   EUNOMIA_CDM        por defecto 5.3          (Synthea27Nj solo existe en 5.4)
# =============================================================================
import os
import sys
import urllib.request
import zipfile
from pathlib import Path

import duckdb

# Reutilizamos el lector de consultas de correr_consultas.py (misma carpeta)
sys.path.insert(0, str(Path(__file__).resolve().parent))
from correr_consultas import leer_consultas, elegir, ejecutar, mostrar  # noqa: E402

LAB_DIR = Path(os.environ.get("LAB12_DIR", str(Path.home() / "s12-omop-cdm-introduccion")))
OMOP_DB = Path(os.environ.get("LAB12_DB", str(LAB_DIR / "omop.duckdb")))
DATASET = os.environ.get("EUNOMIA_DATASET", "GiBleed")
CDM = os.environ.get("EUNOMIA_CDM", "5.3")

URL = (f"https://raw.githubusercontent.com/OHDSI/EunomiaDatasets/main/"
       f"datasets/{DATASET}/{DATASET}_{CDM}.zip")
CARPETA = LAB_DIR / "eunomia"
ZIP = CARPETA / f"{DATASET}_{CDM}.zip"
CSV_DIR = CARPETA / f"{DATASET}_{CDM}"
EUNOMIA_DB = LAB_DIR / "eunomia.duckdb"


def descargar():
    CARPETA.mkdir(parents=True, exist_ok=True)
    if ZIP.exists() and ZIP.stat().st_size > 0:
        print(f"- Zip ya descargado: {ZIP}")
        return
    print(f"- Descargando {URL}")
    tmp = ZIP.with_suffix(".part")
    urllib.request.urlretrieve(URL, tmp)
    tmp.rename(ZIP)
    print(f"  {ZIP.stat().st_size / 1e6:.1f} MB guardados en {ZIP}")


def descomprimir():
    """Extrae solo los .csv (ignora la basura __MACOSX de los zips hechos en Mac)."""
    CSV_DIR.mkdir(parents=True, exist_ok=True)
    n = 0
    with zipfile.ZipFile(ZIP) as z:
        for info in z.infolist():
            nombre = info.filename
            if "__MACOSX" in nombre or not nombre.lower().endswith(".csv"):
                continue
            destino = CSV_DIR / Path(nombre).name
            with z.open(info) as src, open(destino, "wb") as dst:
                dst.write(src.read())
            n += 1
    print(f"- {n} CSV extraídos en {CSV_DIR}")


def cargar():
    """Una tabla por CSV. Columnas en minúscula. Fechas-hora con 'Z' -> TIMESTAMP (UTC)."""
    if EUNOMIA_DB.exists():
        EUNOMIA_DB.unlink()
    con = duckdb.connect(str(EUNOMIA_DB))
    for csv in sorted(CSV_DIR.glob("*.csv")):
        tabla = csv.stem.lower()
        lectura = f"read_csv('{csv.as_posix()}', header=true, sample_size=-1)"
        columnas = con.execute(f"DESCRIBE SELECT * FROM {lectura}").fetchall()
        partes = []
        for nombre, tipo, *_ in columnas:
            if tipo == "TIMESTAMP WITH TIME ZONE":
                partes.append(f'timezone(\'UTC\', "{nombre}") AS {nombre.lower()}')
            else:
                partes.append(f'"{nombre}" AS {nombre.lower()}')
        con.execute(f"CREATE OR REPLACE TABLE {tabla} AS SELECT {', '.join(partes)} FROM {lectura}")
    filas = con.execute("""
        SELECT table_name, estimated_size FROM duckdb_tables() ORDER BY table_name
    """).fetchall()
    print(f"- {len(filas)} tablas cargadas en {EUNOMIA_DB}")
    con.close()


def contar(con, tabla):
    return con.execute(f"SELECT count(*) FROM {tabla}").fetchone()[0]


def vocabulario(con):
    print()
    print("Subconjunto de vocabulario incluido en Eunomia:")
    for t in ["concept", "concept_relationship", "concept_ancestor", "vocabulary", "domain"]:
        try:
            print(f"  {t:<22}{contar(con, t):>10,} filas")
        except duckdb.Error:
            print(f"  {t:<22}{'(no está)':>10}")
    df = con.execute("""
        SELECT vocabulary_id, domain_id, count(*) AS conceptos,
               count(*) FILTER (WHERE standard_concept = 'S') AS estandar
        FROM concept GROUP BY 1, 2 ORDER BY conceptos DESC
    """).df()
    mostrar(df)
    try:
        df = con.execute("SELECT cdm_source_name, cdm_version, vocabulary_version FROM cdm_source").df()
        print()
        mostrar(df)
    except duckdb.Error:
        pass


RESUMEN_SQL = [
    ("Personas", "SELECT count(DISTINCT person_id) FROM person"),
    ("% mujeres (8532 FEMALE)",
     "SELECT round(100.0 * count(DISTINCT person_id) FILTER (WHERE gender_concept_id = 8532)"
     " / count(DISTINCT person_id), 1) FROM person"),
    ("Año de nacimiento (mediana)", "SELECT median(year_of_birth) FROM person"),
    ("Mediana días de observación",
     "SELECT median(d) FROM (SELECT person_id, sum(date_diff('day', observation_period_start_date,"
     " observation_period_end_date)) AS d FROM observation_period"
     " WHERE person_id IN (SELECT person_id FROM person) GROUP BY person_id)"),
    ("Periodos de obs. sin persona en PERSON",
     "SELECT count(*) FROM observation_period WHERE person_id NOT IN (SELECT person_id FROM person)"),
    ("Visitas totales", "SELECT count(*) FROM visit_occurrence"),
    ("Visitas por persona",
     "SELECT round(count(*) / (SELECT count(DISTINCT person_id) FROM person), 2) FROM visit_occurrence"),
    ("Eventos de condición", "SELECT count(*) FROM condition_occurrence"),
    ("Personas con >=1 condición", "SELECT count(DISTINCT person_id) FROM condition_occurrence"),
    ("Conceptos de condición distintos", "SELECT count(DISTINCT condition_concept_id) FROM condition_occurrence"),
    ("% condition_concept_id = 0",
     "SELECT round(100.0 * count(*) FILTER (WHERE condition_concept_id = 0) / count(*), 2) FROM condition_occurrence"),
    ("% visit_concept_id = 0",
     "SELECT round(100.0 * count(*) FILTER (WHERE visit_concept_id = 0) / count(*), 2) FROM visit_occurrence"),
]


def valor(con, sql):
    if con is None:
        return "-"
    try:
        v = con.execute(sql).fetchone()[0]
        return f"{v:,}" if isinstance(v, int) else str(v)
    except duckdb.Error:
        return "error"


def main():
    print("=" * 100)
    print(f"ACTIVIDAD 10 — Eunomia {DATASET} (CDM {CDM}) vs tu conversión Synthea")
    print("=" * 100)
    try:
        descargar()
    except Exception as e:  # sin internet, URL caída, etc.
        sys.exit(f"ERROR descargando {URL}: {e}")
    descomprimir()
    cargar()

    eu = duckdb.connect(str(EUNOMIA_DB), read_only=True)
    om = duckdb.connect(str(OMOP_DB), read_only=True) if OMOP_DB.exists() else None
    if om is None:
        print(f"(Aviso: no existe {OMOP_DB}; solo se mostrará Eunomia)")

    vocabulario(eu)

    # Mismas consultas de la actividad 6
    for cid, pregunta, sql in elegir(leer_consultas(), ["6"]):
        print()
        print("=" * 100)
        print(f"CONSULTA {cid} | {pregunta}")
        print("=" * 100)
        for etiqueta, con in [(f"[Eunomia {DATASET}]", eu), ("[Tu Synthea -> OMOP]", om)]:
            if con is None:
                continue
            print(etiqueta)
            try:
                mostrar(ejecutar(con, sql), max_filas=25)
            except duckdb.Error as e:
                print(f"   ERROR: {e}")
            print()

    # Tabla resumen
    print("=" * 100)
    print("RESUMEN COMPARATIVO")
    print("=" * 100)
    print(f"  {'indicador':<36}{'Eunomia ' + DATASET:>20}{'Synthea -> OMOP':>20}")
    print("  " + "-" * 76)
    for nombre, sql in RESUMEN_SQL:
        print(f"  {nombre:<36}{valor(eu, sql):>20}{valor(om, sql):>20}")
    eu.close()
    if om is not None:
        om.close()


if __name__ == "__main__":
    main()
