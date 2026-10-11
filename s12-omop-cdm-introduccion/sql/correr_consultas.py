#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# Laboratorio 12 — Ejecuta las consultas de sql/consultas_omop.sql
#
# Uso (con el venv activado):
#   python sql/correr_consultas.py            -> todas las consultas
#   python sql/correr_consultas.py 6          -> solo la actividad 6
#   python sql/correr_consultas.py 5.1 7.2    -> consultas concretas
#
# Cada consulta del .sql empieza con una línea separadora:
#   -- >>> CONSULTA 6.2 | ¿pregunta?
# Este script corta el fichero por esas líneas y ejecuta cada bloque.
#
# Variables de entorno opcionales: LAB12_DIR, LAB12_DB (igual que los otros scripts)
# =============================================================================
import os
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd

LAB_DIR = Path(os.environ.get("LAB12_DIR", str(Path.home() / "s12-omop-cdm-introduccion")))
DB_PATH = Path(os.environ.get("LAB12_DB", str(LAB_DIR / "omop.duckdb")))
SQL_FILE = Path(__file__).resolve().parent / "consultas_omop.sql"

SEPARADOR = re.compile(r"^--\s*>>>\s*CONSULTA\s+([0-9]+(?:\.[0-9]+)*)\s*\|\s*(.*)$")


def leer_consultas(ruta=SQL_FILE):
    """Devuelve una lista de (id, pregunta, sql) a partir del fichero .sql."""
    consultas = []
    actual = None
    for linea in Path(ruta).read_text(encoding="utf-8").splitlines():
        m = SEPARADOR.match(linea.strip())
        if m:
            if actual:
                consultas.append(actual)
            actual = [m.group(1), m.group(2).strip(), []]
        elif actual is not None:
            actual[2].append(linea)
    if actual:
        consultas.append(actual)
    resultado = []
    for cid, pregunta, lineas in consultas:
        sql = "\n".join(lineas).strip()
        # ¿hay algo más que comentarios?
        codigo = [l for l in lineas if l.strip() and not l.strip().startswith("--")]
        if codigo:
            resultado.append((cid, pregunta, sql))
    return resultado


def elegir(consultas, filtros):
    """Filtra por número: '6' -> 6.1, 6.2...; '6.2' -> solo 6.2."""
    if not filtros:
        return consultas
    elegidas = []
    for c in consultas:
        for f in filtros:
            if c[0] == f or c[0].startswith(f + "."):
                elegidas.append(c)
                break
    return elegidas


def ejecutar(con, sql):
    """Ejecuta un bloque y devuelve un DataFrame de pandas."""
    return con.execute(sql).df()


def mostrar(df, max_filas=60):
    with pd.option_context("display.max_rows", max_filas, "display.max_columns", 50,
                           "display.width", 200, "display.max_colwidth", 60):
        if df.empty:
            print("   (sin filas)")
        else:
            print(df.to_string(index=False, max_rows=max_filas))


def main():
    filtros = sys.argv[1:]
    if not DB_PATH.exists():
        sys.exit(f"ERROR: no existe {DB_PATH}. Ejecuta antes cargar_vocab.py y convertir.py")
    consultas = elegir(leer_consultas(), filtros)
    if not consultas:
        sys.exit(f"No hay consultas que coincidan con: {' '.join(filtros)}")

    con = duckdb.connect(str(DB_PATH), read_only=True)
    print(f"Base de datos: {DB_PATH}")
    print(f"Consultas    : {SQL_FILE}  ({len(consultas)} seleccionadas)")
    errores = 0
    for cid, pregunta, sql in consultas:
        print()
        print("=" * 100)
        print(f"CONSULTA {cid} | {pregunta}")
        print("=" * 100)
        try:
            mostrar(ejecutar(con, sql))
        except duckdb.Error as e:
            errores += 1
            print(f"   ERROR: {e}")
            if "does not exist" in str(e):
                print("   (¿La tabla no existe? Las consultas 'Opcional' necesitan las tablas opcionales.)")
    con.close()
    print()
    print(f"Fin. Consultas ejecutadas: {len(consultas)}, con error: {errores}")


if __name__ == "__main__":
    main()
