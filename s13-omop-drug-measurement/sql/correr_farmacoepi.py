#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# Laboratorio 13 — Ejecuta las consultas de sql/farmacoepi.sql
#
# Uso (con el venv activado, desde la carpeta del lab 13):
#   python sql/correr_farmacoepi.py              -> todas las consultas, en orden
#   python sql/correr_farmacoepi.py 4            -> solo la actividad 4
#   python sql/correr_farmacoepi.py 0 5.2        -> parámetros + consulta 5.2
#   python sql/correr_farmacoepi.py --crear      -> solo crea las tablas results.*
#
# IMPORTANTE: escribe tablas nuevas en el esquema "results" de omop.duckdb,
# así que abre la base en modo escritura. Cierra antes DBeaver, la CLI de
# DuckDB y el notebook (Kernel -> Shut Down), o DuckDB dirá que el fichero
# está bloqueado ("Could not set lock on file").
#
# Variables de entorno opcionales:
#   LAB13_DB     base OMOP   (por defecto ~/s12-omop-cdm-introduccion/omop.duckdb)
#   SYNTHEA_CSV  CSV Synthea (por defecto ~/s10-sql-fundamentals/synthea/output/csv)
# =============================================================================
import os
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd

DB_PATH = Path(os.environ.get(
    "LAB13_DB", str(Path.home() / "s12-omop-cdm-introduccion" / "omop.duckdb")))
SYNTHEA_CSV = Path(os.environ.get(
    "SYNTHEA_CSV", str(Path.home() / "s10-sql-fundamentals" / "synthea" / "output" / "csv")))
SQL_FILE = Path(__file__).resolve().parent / "farmacoepi.sql"

SEPARADOR = re.compile(r"^--\s*>>>\s*CONSULTA\s+([0-9]+(?:\.[0-9]+)*)\s*\|\s*(.*)$")


def leer_consultas(ruta=SQL_FILE):
    """Lista de (id, pregunta, sql) leída del fichero .sql."""
    bloques, actual = [], None
    for linea in Path(ruta).read_text(encoding="utf-8").splitlines():
        m = SEPARADOR.match(linea.strip())
        if m:
            if actual:
                bloques.append(actual)
            actual = [m.group(1), m.group(2).strip(), []]
        elif actual is not None:
            actual[2].append(linea)
    if actual:
        bloques.append(actual)
    salida = []
    for cid, pregunta, lineas in bloques:
        if any(l.strip() and not l.strip().startswith("--") for l in lineas):
            salida.append((cid, pregunta, "\n".join(lineas).strip()))
    return salida


def elegir(consultas, filtros):
    """'6' -> 6.1, 6.2...; '6.2' -> solo 6.2."""
    if not filtros:
        return consultas
    return [c for c in consultas
            if any(c[0] == f or c[0].startswith(f + ".") for f in filtros)]


def es_creacion(consulta):
    return consulta[1].startswith("[CREA")


def preparar(sql):
    """Sustituye {{SYNTHEA_CSV}} por la carpeta real de Synthea."""
    return sql.replace("{{SYNTHEA_CSV}}", SYNTHEA_CSV.as_posix())


def conectar(solo_lectura=False):
    if not DB_PATH.exists():
        sys.exit(f"ERROR: no existe {DB_PATH} (¿hiciste el Lab 12?)")
    try:
        return duckdb.connect(str(DB_PATH), read_only=solo_lectura)
    except duckdb.IOException as e:
        if "lock" in str(e).lower():
            sys.exit("ERROR: omop.duckdb está BLOQUEADA por otro programa (notebook, DBeaver,\n"
                     "CLI de DuckDB...). Ciérralo (en Jupyter: Kernel -> Shut Down Kernel)\n"
                     f"y vuelve a intentarlo.\nDetalle: {e}")
        raise


def ultima_sentencia(sql):
    """Solo la última sentencia del bloque (el SELECT de resumen), sin comentarios."""
    sin_comentarios = "\n".join(l for l in sql.splitlines() if not l.strip().startswith("--"))
    partes = [p.strip() for p in sin_comentarios.split(";") if p.strip()]
    return partes[-1]


def ejecutar(con, sql, solo_resumen=False):
    """Ejecuta un bloque (puede tener varias sentencias) y devuelve un DataFrame
    con el resultado de la ÚLTIMA sentencia. Con solo_resumen=True ejecuta solo
    esa última sentencia (sirve con una conexión de solo lectura)."""
    if solo_resumen:
        sql = ultima_sentencia(sql)
    return con.execute(preparar(sql)).df()


def mostrar(df, max_filas=40):
    with pd.option_context("display.max_rows", max_filas, "display.max_columns", 50,
                           "display.width", 220, "display.max_colwidth", 70):
        print("   (sin filas)" if df.empty else df.to_string(index=False, max_rows=max_filas))


def crear_results(con=None, verbose=True):
    """Ejecuta, en orden, todas las consultas [CREA ...] (tablas results.*)."""
    propia = con is None
    if propia:
        con = conectar()
    for cid, pregunta, sql in leer_consultas():
        if es_creacion((cid, pregunta, sql)):
            if verbose:
                print(f"- {cid}: {pregunta[:90]}")
            con.execute(preparar(sql))
    if propia:
        con.close()


def results_completo(con):
    """¿Están ya creadas todas las tablas results.* que usa el notebook?"""
    necesarias = {"parametros", "exposicion_ingrediente", "cobertura_ingrediente",
                  "drug_era_ingrediente", "pdc_ingrediente", "measurement_normalizada",
                  "rangos_plausibles", "measurement_plausibilidad", "indice_basal"}
    filas = con.execute("SELECT table_name FROM information_schema.tables "
                        "WHERE table_schema = 'results'").fetchall()
    return necesarias.issubset({f[0] for f in filas})


def main():
    args = sys.argv[1:]
    if args == ["--crear"]:
        print(f"Creando tablas results.* en {DB_PATH}")
        crear_results()
        print("Listo.")
        return
    consultas = elegir(leer_consultas(), args)
    if not consultas:
        sys.exit(f"No hay consultas que coincidan con: {' '.join(args)}")
    con = conectar()
    print(f"Base de datos: {DB_PATH}")
    print(f"Synthea CSV  : {SYNTHEA_CSV}")
    print(f"Consultas    : {SQL_FILE.name} ({len(consultas)} seleccionadas)")
    errores = 0
    for cid, pregunta, sql in consultas:
        print("\n" + "=" * 110)
        print(f"CONSULTA {cid} | {pregunta}")
        print("=" * 110)
        try:
            mostrar(ejecutar(con, sql))
        except duckdb.Error as e:
            errores += 1
            print(f"   ERROR: {e}")
            if "results" in str(e) and "does not exist" in str(e):
                print("   (Falta una tabla results.*: ejecuta antes la consulta [CREA] de esa actividad, "
                      "o todo: python sql/correr_farmacoepi.py)")
    con.close()
    print(f"\nFin. Consultas ejecutadas: {len(consultas)}, con error: {errores}")


if __name__ == "__main__":
    main()
