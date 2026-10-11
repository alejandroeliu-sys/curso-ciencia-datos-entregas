#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# Laboratorio 12 — Primeros pasos en OMOP CDM v5.4
# PASO 1: cargar los vocabularios de ATHENA en omop.duckdb
#
# Qué hace:
#   - Lee los CSV de ATHENA (separados por TABULADOR, fechas YYYYMMDD,
#     comillas SIN escapar) desde ~/s12-omop-cdm-introduccion/vocab/
#   - Crea (o re-crea) las tablas concept, concept_relationship,
#     concept_ancestor y, si existen, vocabulary, domain, concept_class y
#     relationship, con las columnas y tipos de la DDL oficial OMOP CDM v5.4.
#   - Imprime cuántas filas tiene cada tabla y cuántos conceptos estándar
#     (standard_concept = 'S') hay.
#
# Cómo se ejecuta (con el venv activado):
#   python sql/cargar_vocab.py
#
# Se puede ejecutar las veces que quieras: CREATE OR REPLACE borra y re-crea.
# Variables de entorno opcionales (solo si quieres otras rutas):
#   LAB12_DIR   carpeta del lab   (por defecto ~/s12-omop-cdm-introduccion)
#   LAB12_VOCAB carpeta de vocab  (por defecto LAB12_DIR/vocab)
#   LAB12_DB    base de datos     (por defecto LAB12_DIR/omop.duckdb)
# =============================================================================
import os
import sys
import time
from pathlib import Path

import duckdb

LAB_DIR = Path(os.environ.get("LAB12_DIR", str(Path.home() / "s12-omop-cdm-introduccion")))
VOCAB_DIR = Path(os.environ.get("LAB12_VOCAB", str(LAB_DIR / "vocab")))
DB_PATH = Path(os.environ.get("LAB12_DB", str(LAB_DIR / "omop.duckdb")))

# -----------------------------------------------------------------------------
# DDL oficial OMOP CDM v5.4 (OHDSI/CommonDataModel) adaptada a DuckDB.
# El orden de las columnas es el MISMO que el de los CSV de ATHENA.
# obligatoria=True -> si falta el fichero, el script se detiene.
# -----------------------------------------------------------------------------
TABLAS = [
    ("concept", "CONCEPT.csv", True, [
        ("concept_id", "INTEGER NOT NULL"),
        ("concept_name", "VARCHAR(255) NOT NULL"),
        ("domain_id", "VARCHAR(20) NOT NULL"),
        ("vocabulary_id", "VARCHAR(20) NOT NULL"),
        ("concept_class_id", "VARCHAR(20) NOT NULL"),
        ("standard_concept", "VARCHAR(1)"),
        ("concept_code", "VARCHAR(50) NOT NULL"),
        ("valid_start_date", "DATE NOT NULL"),
        ("valid_end_date", "DATE NOT NULL"),
        ("invalid_reason", "VARCHAR(1)"),
    ]),
    ("concept_relationship", "CONCEPT_RELATIONSHIP.csv", True, [
        ("concept_id_1", "INTEGER NOT NULL"),
        ("concept_id_2", "INTEGER NOT NULL"),
        ("relationship_id", "VARCHAR(20) NOT NULL"),
        ("valid_start_date", "DATE NOT NULL"),
        ("valid_end_date", "DATE NOT NULL"),
        ("invalid_reason", "VARCHAR(1)"),
    ]),
    ("concept_ancestor", "CONCEPT_ANCESTOR.csv", True, [
        ("ancestor_concept_id", "INTEGER NOT NULL"),
        ("descendant_concept_id", "INTEGER NOT NULL"),
        ("min_levels_of_separation", "INTEGER NOT NULL"),
        ("max_levels_of_separation", "INTEGER NOT NULL"),
    ]),
    ("vocabulary", "VOCABULARY.csv", False, [
        ("vocabulary_id", "VARCHAR(20) NOT NULL"),
        ("vocabulary_name", "VARCHAR(255) NOT NULL"),
        ("vocabulary_reference", "VARCHAR(255)"),
        ("vocabulary_version", "VARCHAR(255)"),
        ("vocabulary_concept_id", "INTEGER NOT NULL"),
    ]),
    ("domain", "DOMAIN.csv", False, [
        ("domain_id", "VARCHAR(20) NOT NULL"),
        ("domain_name", "VARCHAR(255) NOT NULL"),
        ("domain_concept_id", "INTEGER NOT NULL"),
    ]),
    ("concept_class", "CONCEPT_CLASS.csv", False, [
        ("concept_class_id", "VARCHAR(20) NOT NULL"),
        ("concept_class_name", "VARCHAR(255) NOT NULL"),
        ("concept_class_concept_id", "INTEGER NOT NULL"),
    ]),
    ("relationship", "RELATIONSHIP.csv", False, [
        ("relationship_id", "VARCHAR(20) NOT NULL"),
        ("relationship_name", "VARCHAR(255) NOT NULL"),
        ("is_hierarchical", "VARCHAR(1) NOT NULL"),
        ("defines_ancestry", "VARCHAR(1) NOT NULL"),
        ("reverse_relationship_id", "VARCHAR(20) NOT NULL"),
        ("relationship_concept_id", "INTEGER NOT NULL"),
    ]),
]

# Conceptos que convertir.py va a usar: comprobamos que existen en CONCEPT
CONCEPTOS_CLAVE = [8507, 8532, 9201, 9202, 9203, 32817, 38003563, 38003564]


def buscar_fichero(nombre):
    """Busca el fichero sin importar mayúsculas/minúsculas (CONCEPT.csv o concept.csv)."""
    for p in VOCAB_DIR.iterdir():
        if p.name.lower() == nombre.lower():
            return p
    return None


def tipo_lectura(tipo_ddl):
    """Para leer el CSV usamos el tipo base (sin NOT NULL)."""
    return tipo_ddl.replace(" NOT NULL", "")


def main():
    print("=" * 70)
    print("PASO 1 — Carga de vocabularios ATHENA")
    print(f"  Carpeta de vocabulario : {VOCAB_DIR}")
    print(f"  Base de datos OMOP     : {DB_PATH}")
    print("=" * 70)

    if not VOCAB_DIR.is_dir():
        sys.exit(f"ERROR: no existe la carpeta {VOCAB_DIR}\n"
                 "Descomprime ahí el zip de ATHENA (debe contener CONCEPT.csv, etc.).")

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH))

    resumen = []
    for tabla, fichero, obligatoria, columnas in TABLAS:
        ruta = buscar_fichero(fichero)
        if ruta is None:
            if obligatoria:
                con.close()
                sys.exit(f"ERROR: falta {fichero} en {VOCAB_DIR}")
            print(f"- {fichero}: no está (opcional), se omite.")
            continue

        t0 = time.time()
        print(f"- Cargando {fichero} -> tabla {tabla} ...", end=" ", flush=True)

        # 1) Crear la tabla vacía con la DDL v5.4
        ddl = ",\n  ".join(f"{c} {t}" for c, t in columnas)
        con.execute(f"CREATE OR REPLACE TABLE {tabla} (\n  {ddl}\n)")

        # 2) Leer el CSV de ATHENA:
        #    delim='\t'  -> separado por tabulador
        #    quote=''    -> SIN comillas (ATHENA no escapa las comillas dobles)
        #    dateformat  -> fechas tipo 20240131
        tipos = ", ".join(f"'{c}': '{tipo_lectura(t)}'" for c, t in columnas)
        lectura = (
            f"read_csv('{ruta.as_posix()}', delim='\\t', header=true, "
            f"quote='', escape='', dateformat='%Y%m%d', "
            f"columns={{{tipos}}})"
        )
        con.execute(f"INSERT INTO {tabla} SELECT * FROM {lectura}")
        n = con.execute(f"SELECT count(*) FROM {tabla}").fetchone()[0]
        print(f"{n:,} filas ({time.time() - t0:.1f} s)")
        resumen.append((tabla, n))

    # Conceptos estándar
    n_std = con.execute("SELECT count(*) FROM concept WHERE standard_concept = 'S'").fetchone()[0]

    print()
    print("RESUMEN")
    print("-" * 45)
    for tabla, n in resumen:
        print(f"  {tabla:<25}{n:>18,}")
    print("-" * 45)
    print(f"  {'conceptos estándar (S)':<25}{n_std:>18,}")
    print()

    print("Conceptos por vocabulario (total y estándar):")
    filas = con.execute("""
        SELECT vocabulary_id,
               count(*) AS total,
               count(*) FILTER (WHERE standard_concept = 'S') AS estandar
        FROM concept
        GROUP BY vocabulary_id
        ORDER BY total DESC
        LIMIT 25
    """).fetchall()
    for voc, tot, std in filas:
        print(f"  {voc:<25}{tot:>12,}{std:>12,}")
    print()

    print("Comprobación de conceptos que usará convertir.py:")
    for cid in CONCEPTOS_CLAVE:
        fila = con.execute(
            "SELECT concept_name, vocabulary_id, standard_concept FROM concept WHERE concept_id = ?",
            [cid]).fetchone()
        if fila:
            print(f"  OK  {cid:<10} {fila[0]} ({fila[1]}, standard={fila[2]})")
        else:
            print(f"  ??  {cid:<10} NO está en CONCEPT (¿faltó marcar ese vocabulario en ATHENA?)")

    con.close()
    print("\nListo. Ahora ejecuta: python sql/convertir.py")


if __name__ == "__main__":
    main()
