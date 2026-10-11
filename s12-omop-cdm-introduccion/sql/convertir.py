#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# Laboratorio 12 — Primeros pasos en OMOP CDM v5.4
# PASO 2: convertir los CSV de Synthea (Lab 10) a tablas OMOP CDM v5.4
#
# Ruta elegida: "A mano (SQL)" dentro de DuckDB.
# Tablas OBLIGATORIAS: person, observation_period, visit_occurrence,
#                      condition_occurrence
# Tablas OPCIONALES  : drug_exposure (medications.csv) y
#                      measurement (observations.csv, solo laboratorio y
#                      signos vitales numéricos). Se apagan con
#                      INCLUIR_OPCIONALES = False.
#
# REQUISITO: antes hay que ejecutar sql/cargar_vocab.py (los vocabularios
#            se cargan ANTES de convertir, porque el mapeo usa CONCEPT y
#            CONCEPT_RELATIONSHIP).
#
# Cómo se ejecuta (con el venv activado):
#   python sql/convertir.py
# Se puede repetir: cada tabla se re-crea con CREATE OR REPLACE.
#
# Variables de entorno opcionales:
#   LAB12_DIR    carpeta del lab   (por defecto ~/s12-omop-cdm-introduccion)
#   LAB12_DB     base OMOP         (por defecto LAB12_DIR/omop.duckdb)
#   SYNTHEA_CSV  CSV de Synthea    (por defecto ~/s10-sql-fundamentals/synthea/output/csv)
# =============================================================================
import os
import sys
import time
from pathlib import Path

import duckdb

LAB_DIR = Path(os.environ.get("LAB12_DIR", str(Path.home() / "s12-omop-cdm-introduccion")))
DB_PATH = Path(os.environ.get("LAB12_DB", str(LAB_DIR / "omop.duckdb")))
SYNTHEA_CSV = Path(os.environ.get(
    "SYNTHEA_CSV", str(Path.home() / "s10-sql-fundamentals" / "synthea" / "output" / "csv")))

INCLUIR_OPCIONALES = True   # drug_exposure y measurement

# Concepto de "tipo de registro": 32817 = EHR (vocabulario Type Concept)
TIPO_EHR = 32817

# -----------------------------------------------------------------------------
# Tablas de mapeo "a mano" (valor de Synthea -> concept_id estándar OMOP)
# -----------------------------------------------------------------------------
GENERO = {"M": 8507,   # MALE
          "F": 8532}   # FEMALE

RAZA = {"white": 8527,      # White
        "black": 8516,      # Black or African American
        "asian": 8515,      # Asian
        "native": 8657,     # American Indian or Alaska Native
        "hawaiian": 8557}   # Native Hawaiian or Other Pacific Islander
# 'other' -> 0 (no hay concepto estándar "Other Race"; 8522 no es estándar)

ETNIA = {"hispanic": 38003563,      # Hispanic or Latino
         "nonhispanic": 38003564}   # Not Hispanic or Latino

# ENCOUNTERCLASS de Synthea -> visit_concept_id
# Igual que el ETL oficial de OHDSI (ETL-Synthea, v5.4):
#   ambulatory / wellness / outpatient -> 9202 Outpatient Visit
#   emergency  / urgentcare            -> 9203 Emergency Room Visit
#   inpatient                          -> 9201 Inpatient Visit
#   resto (virtual, home, hospice, snf) -> 0  (sin mapeo; quedan visibles
#                                            en la actividad 5)
# Alternativa más precisa para urgentcare: 8782 "Urgent Care Facility"
# (concepto estándar del dominio Visit). Si la prefieres, cambia 9203 por 8782.
VISITA = {"ambulatory": 9202,
          "wellness": 9202,
          "outpatient": 9202,
          "emergency": 9203,
          "urgentcare": 9203,
          "inpatient": 9201}


def case_sql(columna, mapa, por_defecto="0"):
    """Construye un CASE ... WHEN ... a partir de un diccionario de Python."""
    partes = [f"WHEN '{k}' THEN {v}" for k, v in mapa.items()]
    return f"CASE {columna} " + " ".join(partes) + f" ELSE {por_defecto} END"


def leer_csv(con, nombre_tabla, fichero):
    """Carga un CSV de Synthea como tabla temporal, TODO como texto.
    (Así controlamos nosotros la conversión de fechas y evitamos problemas
    de zona horaria con las fechas tipo 2016-12-14T01:44:17Z.)"""
    ruta = SYNTHEA_CSV / fichero
    if not ruta.exists():
        return False
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE {nombre_tabla} AS
        SELECT * FROM read_csv('{ruta.as_posix()}', header=true, all_varchar=true)
    """)
    return True


# Subconsulta reutilizable: código fuente -> concepto fuente -> concepto estándar
# vocab = 'SNOMED' (condiciones), 'RxNorm' (medicamentos), 'LOINC' (mediciones)
def mapa_vocab(vocab):
    return f"""
    (
      SELECT src.concept_code,
             src.concept_id AS source_concept_id,
             COALESCE(m.concept_id_2,
                      CASE WHEN src.standard_concept = 'S' THEN src.concept_id END,
                      0) AS standard_concept_id
      FROM (
          SELECT concept_code, concept_id, standard_concept
          FROM concept
          WHERE vocabulary_id = '{vocab}'
          -- por seguridad: un solo concepto por código (el vigente primero)
          QUALIFY row_number() OVER (PARTITION BY concept_code
                                     ORDER BY invalid_reason NULLS FIRST, concept_id) = 1
      ) src
      LEFT JOIN (
          SELECT cr.concept_id_1, cr.concept_id_2
          FROM concept_relationship cr
          JOIN concept c2 ON c2.concept_id = cr.concept_id_2
          WHERE cr.relationship_id = 'Maps to'
            AND cr.invalid_reason IS NULL
            AND c2.standard_concept = 'S'
      ) m ON m.concept_id_1 = src.concept_id
    )"""


DDL = {
    "person": """
        CREATE OR REPLACE TABLE person (
            person_id                   INTEGER NOT NULL PRIMARY KEY,
            gender_concept_id           INTEGER NOT NULL,
            year_of_birth               INTEGER NOT NULL,
            month_of_birth              INTEGER,
            day_of_birth                INTEGER,
            birth_datetime              TIMESTAMP,
            race_concept_id             INTEGER NOT NULL,
            ethnicity_concept_id        INTEGER NOT NULL,
            location_id                 INTEGER,
            provider_id                 INTEGER,
            care_site_id                INTEGER,
            person_source_value         VARCHAR(50),
            gender_source_value         VARCHAR(50),
            gender_source_concept_id    INTEGER,
            race_source_value           VARCHAR(50),
            race_source_concept_id      INTEGER,
            ethnicity_source_value      VARCHAR(50),
            ethnicity_source_concept_id INTEGER
        )""",
    "observation_period": """
        CREATE OR REPLACE TABLE observation_period (
            observation_period_id         INTEGER NOT NULL PRIMARY KEY,
            person_id                     INTEGER NOT NULL,
            observation_period_start_date DATE NOT NULL,
            observation_period_end_date   DATE NOT NULL,
            period_type_concept_id        INTEGER NOT NULL
        )""",
    "visit_occurrence": """
        CREATE OR REPLACE TABLE visit_occurrence (
            visit_occurrence_id           INTEGER NOT NULL PRIMARY KEY,
            person_id                     INTEGER NOT NULL,
            visit_concept_id              INTEGER NOT NULL,
            visit_start_date              DATE NOT NULL,
            visit_start_datetime          TIMESTAMP,
            visit_end_date                DATE NOT NULL,
            visit_end_datetime            TIMESTAMP,
            visit_type_concept_id         INTEGER NOT NULL,
            provider_id                   INTEGER,
            care_site_id                  INTEGER,
            visit_source_value            VARCHAR(50),
            visit_source_concept_id       INTEGER,
            admitted_from_concept_id      INTEGER,
            admitted_from_source_value    VARCHAR(50),
            discharged_to_concept_id      INTEGER,
            discharged_to_source_value    VARCHAR(50),
            preceding_visit_occurrence_id INTEGER
        )""",
    "condition_occurrence": """
        CREATE OR REPLACE TABLE condition_occurrence (
            condition_occurrence_id       INTEGER NOT NULL PRIMARY KEY,
            person_id                     INTEGER NOT NULL,
            condition_concept_id          INTEGER NOT NULL,
            condition_start_date          DATE NOT NULL,
            condition_start_datetime      TIMESTAMP,
            condition_end_date            DATE,
            condition_end_datetime        TIMESTAMP,
            condition_type_concept_id     INTEGER NOT NULL,
            condition_status_concept_id   INTEGER,
            stop_reason                   VARCHAR(20),
            provider_id                   INTEGER,
            visit_occurrence_id           INTEGER,
            visit_detail_id               INTEGER,
            condition_source_value        VARCHAR(50),
            condition_source_concept_id   INTEGER,
            condition_status_source_value VARCHAR(50)
        )""",
    "drug_exposure": """
        CREATE OR REPLACE TABLE drug_exposure (
            drug_exposure_id             INTEGER NOT NULL PRIMARY KEY,
            person_id                    INTEGER NOT NULL,
            drug_concept_id              INTEGER NOT NULL,
            drug_exposure_start_date     DATE NOT NULL,
            drug_exposure_start_datetime TIMESTAMP,
            drug_exposure_end_date       DATE NOT NULL,
            drug_exposure_end_datetime   TIMESTAMP,
            verbatim_end_date            DATE,
            drug_type_concept_id         INTEGER NOT NULL,
            stop_reason                  VARCHAR(20),
            refills                      INTEGER,
            quantity                     NUMERIC,
            days_supply                  INTEGER,
            sig                          TEXT,
            route_concept_id             INTEGER,
            lot_number                   VARCHAR(50),
            provider_id                  INTEGER,
            visit_occurrence_id          INTEGER,
            visit_detail_id              INTEGER,
            drug_source_value            VARCHAR(50),
            drug_source_concept_id       INTEGER,
            route_source_value           VARCHAR(50),
            dose_unit_source_value       VARCHAR(50)
        )""",
    "measurement": """
        CREATE OR REPLACE TABLE measurement (
            measurement_id                INTEGER NOT NULL PRIMARY KEY,
            person_id                     INTEGER NOT NULL,
            measurement_concept_id        INTEGER NOT NULL,
            measurement_date              DATE NOT NULL,
            measurement_datetime          TIMESTAMP,
            measurement_time              VARCHAR(10),
            measurement_type_concept_id   INTEGER NOT NULL,
            operator_concept_id           INTEGER,
            value_as_number               NUMERIC,
            value_as_concept_id           INTEGER,
            unit_concept_id               INTEGER,
            range_low                     NUMERIC,
            range_high                    NUMERIC,
            provider_id                   INTEGER,
            visit_occurrence_id           INTEGER,
            visit_detail_id               INTEGER,
            measurement_source_value      VARCHAR(50),
            measurement_source_concept_id INTEGER,
            unit_source_value             VARCHAR(50),
            unit_source_concept_id        INTEGER,
            value_source_value            VARCHAR(50),
            measurement_event_id          INTEGER,
            meas_event_field_concept_id   INTEGER
        )""",
}

# NOTA sobre fechas: Synthea escribe '2016-12-14T01:44:17Z' (hora UTC).
#   CAST(LEFT(x, 10) AS DATE)       -> fecha  2016-12-14
#   CAST(LEFT(x, 19) AS TIMESTAMP)  -> fecha+hora 2016-12-14 01:44:17 (UTC)

SQL_PERSON = f"""
INSERT INTO person
SELECT
    row_number() OVER (ORDER BY p.Id)                 AS person_id,
    {case_sql('p.GENDER', GENERO)}                    AS gender_concept_id,
    year(CAST(p.BIRTHDATE AS DATE))                   AS year_of_birth,
    month(CAST(p.BIRTHDATE AS DATE))                  AS month_of_birth,
    day(CAST(p.BIRTHDATE AS DATE))                    AS day_of_birth,
    CAST(CAST(p.BIRTHDATE AS DATE) AS TIMESTAMP)      AS birth_datetime,
    {case_sql('lower(p.RACE)', RAZA)}                 AS race_concept_id,
    {case_sql('lower(p.ETHNICITY)', ETNIA)}           AS ethnicity_concept_id,
    NULL, NULL, NULL,                                 -- location, provider, care_site
    p.Id                                              AS person_source_value,
    p.GENDER                                          AS gender_source_value,
    0                                                 AS gender_source_concept_id,
    p.RACE                                            AS race_source_value,
    0                                                 AS race_source_concept_id,
    p.ETHNICITY                                       AS ethnicity_source_value,
    0                                                 AS ethnicity_source_concept_id
FROM syn_patients p
"""

# Tabla puente temporal: Id de encuentro de Synthea -> visit_occurrence_id
SQL_PUENTE_VISITAS = """
CREATE OR REPLACE TEMP TABLE puente_visitas AS
SELECT
    row_number() OVER (ORDER BY per.person_id, e.START, e.Id) AS visit_occurrence_id,
    e.Id AS encounter_id,
    per.person_id
FROM syn_encounters e
JOIN person per ON per.person_source_value = e.PATIENT
"""

SQL_VISIT = f"""
INSERT INTO visit_occurrence
SELECT
    pv.visit_occurrence_id,
    pv.person_id,
    {case_sql('lower(e.ENCOUNTERCLASS)', VISITA)}     AS visit_concept_id,
    CAST(LEFT(e.START, 10) AS DATE)                   AS visit_start_date,
    CAST(LEFT(e.START, 19) AS TIMESTAMP)              AS visit_start_datetime,
    CAST(LEFT(COALESCE(e.STOP, e.START), 10) AS DATE)       AS visit_end_date,
    CAST(LEFT(COALESCE(e.STOP, e.START), 19) AS TIMESTAMP)  AS visit_end_datetime,
    {TIPO_EHR}                                        AS visit_type_concept_id,
    NULL, NULL,                                       -- provider_id, care_site_id
    e.ENCOUNTERCLASS                                  AS visit_source_value,
    0                                                 AS visit_source_concept_id,
    NULL, NULL, NULL, NULL,                           -- admitted_from / discharged_to
    lag(pv.visit_occurrence_id) OVER (PARTITION BY pv.person_id
                                      ORDER BY pv.visit_occurrence_id)
                                                      AS preceding_visit_occurrence_id
FROM syn_encounters e
JOIN puente_visitas pv ON pv.encounter_id = e.Id
"""

# Un periodo por persona: desde su primera visita hasta el fin de la última
SQL_OBS_PERIOD = f"""
INSERT INTO observation_period
SELECT
    row_number() OVER (ORDER BY person_id) AS observation_period_id,
    person_id,
    min(visit_start_date)                  AS observation_period_start_date,
    max(visit_end_date)                    AS observation_period_end_date,
    {TIPO_EHR}                             AS period_type_concept_id
FROM visit_occurrence
GROUP BY person_id
"""

SQL_CONDITION = f"""
INSERT INTO condition_occurrence
WITH mapa AS {mapa_vocab('SNOMED')}
SELECT
    row_number() OVER (ORDER BY per.person_id, c.START, c.CODE, mapa.standard_concept_id)
                                                   AS condition_occurrence_id,
    per.person_id,
    COALESCE(mapa.standard_concept_id, 0)          AS condition_concept_id,
    CAST(LEFT(c.START, 10) AS DATE)                AS condition_start_date,
    CAST(LEFT(c.START, 10) AS TIMESTAMP)           AS condition_start_datetime,
    CAST(LEFT(c.STOP, 10) AS DATE)                 AS condition_end_date,
    CAST(LEFT(c.STOP, 10) AS TIMESTAMP)            AS condition_end_datetime,
    {TIPO_EHR}                                     AS condition_type_concept_id,
    NULL, NULL, NULL,                              -- status, stop_reason, provider
    pv.visit_occurrence_id,
    NULL                                           AS visit_detail_id,
    c.CODE                                         AS condition_source_value,
    COALESCE(mapa.source_concept_id, 0)            AS condition_source_concept_id,
    NULL                                           AS condition_status_source_value
FROM syn_conditions c
JOIN person per                ON per.person_source_value = c.PATIENT
LEFT JOIN puente_visitas pv    ON pv.encounter_id = c.ENCOUNTER
LEFT JOIN mapa                 ON mapa.concept_code = c.CODE
"""

SQL_DRUG = f"""
INSERT INTO drug_exposure
WITH mapa AS {mapa_vocab('RxNorm')}
SELECT
    row_number() OVER (ORDER BY per.person_id, m.START, m.CODE, mapa.standard_concept_id),
    per.person_id,
    COALESCE(mapa.standard_concept_id, 0),
    CAST(LEFT(m.START, 10) AS DATE),
    CAST(LEFT(m.START, 19) AS TIMESTAMP),
    CAST(LEFT(COALESCE(m.STOP, m.START), 10) AS DATE),
    CAST(LEFT(COALESCE(m.STOP, m.START), 19) AS TIMESTAMP),
    CAST(LEFT(m.STOP, 10) AS DATE)                 AS verbatim_end_date,
    {TIPO_EHR},
    NULL, NULL,                                    -- stop_reason, refills
    TRY_CAST(m.DISPENSES AS NUMERIC)               AS quantity,
    NULL, NULL, NULL, NULL, NULL,                  -- days_supply, sig, route, lot, provider
    pv.visit_occurrence_id,
    NULL,
    m.CODE,
    COALESCE(mapa.source_concept_id, 0),
    NULL, NULL
FROM syn_medications m
JOIN person per             ON per.person_source_value = m.PATIENT
LEFT JOIN puente_visitas pv ON pv.encounter_id = m.ENCOUNTER
LEFT JOIN mapa              ON mapa.concept_code = m.CODE
"""

SQL_MEASUREMENT = f"""
INSERT INTO measurement
WITH mapa AS {mapa_vocab('LOINC')},
unidades AS (
    SELECT concept_code, min(concept_id) AS concept_id
    FROM concept WHERE vocabulary_id = 'UCUM' AND standard_concept = 'S'
    GROUP BY concept_code
)
SELECT
    row_number() OVER (ORDER BY per.person_id, o.DATE, o.CODE, mapa.standard_concept_id),
    per.person_id,
    COALESCE(mapa.standard_concept_id, 0),
    CAST(LEFT(o.DATE, 10) AS DATE),
    CAST(LEFT(o.DATE, 19) AS TIMESTAMP),
    NULL,
    {TIPO_EHR},
    NULL,
    TRY_CAST(o.VALUE AS DOUBLE)                    AS value_as_number,
    NULL,
    COALESCE(u.concept_id, 0)                      AS unit_concept_id,
    NULL, NULL, NULL,
    pv.visit_occurrence_id,
    NULL,
    o.CODE,
    COALESCE(mapa.source_concept_id, 0),
    o.UNITS,
    NULL,
    LEFT(o.VALUE, 50)                              AS value_source_value,
    NULL, NULL
FROM syn_observations o
JOIN person per             ON per.person_source_value = o.PATIENT
LEFT JOIN puente_visitas pv ON pv.encounter_id = o.ENCOUNTER
LEFT JOIN mapa              ON mapa.concept_code = o.CODE
LEFT JOIN unidades u        ON u.concept_code = o.UNITS
WHERE o.CATEGORY IN ('laboratory', 'vital-signs')
  AND o.TYPE = 'numeric'
"""


def paso(con, texto, sql):
    t0 = time.time()
    print(f"- {texto} ...", end=" ", flush=True)
    con.execute(sql)
    print(f"ok ({time.time() - t0:.1f} s)")


def contar(con, tabla):
    return con.execute(f"SELECT count(*) FROM {tabla}").fetchone()[0]


def main():
    print("=" * 70)
    print("PASO 2 — Conversión Synthea -> OMOP CDM v5.4 (a mano, SQL en DuckDB)")
    print(f"  CSV de Synthea : {SYNTHEA_CSV}")
    print(f"  Base OMOP      : {DB_PATH}")
    print("=" * 70)

    if not DB_PATH.exists():
        sys.exit(f"ERROR: no existe {DB_PATH}. Ejecuta primero: python sql/cargar_vocab.py")
    con = duckdb.connect(str(DB_PATH))

    # 0) Los vocabularios TIENEN que estar cargados antes
    try:
        n_concept = contar(con, "concept")
        contar(con, "concept_relationship")
    except duckdb.Error:
        n_concept = 0
    if n_concept == 0:
        con.close()
        sys.exit("ERROR: la tabla concept no existe o está vacía.\n"
                 "Ejecuta primero: python sql/cargar_vocab.py")

    # 1) Leer CSV de Synthea
    obligatorios = [("syn_patients", "patients.csv"), ("syn_encounters", "encounters.csv"),
                    ("syn_conditions", "conditions.csv")]
    opcionales = [("syn_medications", "medications.csv"), ("syn_observations", "observations.csv")]
    for tabla, fichero in obligatorios:
        if not leer_csv(con, tabla, fichero):
            con.close()
            sys.exit(f"ERROR: no encuentro {SYNTHEA_CSV / fichero}")
    hay = {}
    if INCLUIR_OPCIONALES:
        for tabla, fichero in opcionales:
            hay[tabla] = leer_csv(con, tabla, fichero)
    print("- CSV de Synthea leídos")

    # 2) Crear tablas OMOP (DDL v5.4) e insertar
    for t in ["person", "observation_period", "visit_occurrence", "condition_occurrence"]:
        con.execute(DDL[t])
    paso(con, "person", SQL_PERSON)
    paso(con, "puente encuentro -> visita (temporal)", SQL_PUENTE_VISITAS)
    paso(con, "visit_occurrence", SQL_VISIT)
    paso(con, "observation_period", SQL_OBS_PERIOD)
    paso(con, "condition_occurrence", SQL_CONDITION)

    tablas_omop = ["person", "observation_period", "visit_occurrence", "condition_occurrence"]
    if INCLUIR_OPCIONALES and hay.get("syn_medications"):
        con.execute(DDL["drug_exposure"])
        paso(con, "drug_exposure (opcional)", SQL_DRUG)
        tablas_omop.append("drug_exposure")
    if INCLUIR_OPCIONALES and hay.get("syn_observations"):
        con.execute(DDL["measurement"])
        paso(con, "measurement (opcional)", SQL_MEASUREMENT)
        tablas_omop.append("measurement")

    # 3) Resumen: filas en OMOP vs filas en Synthea
    origen = {
        "person": ("patients.csv", "SELECT count(*) FROM syn_patients"),
        "observation_period": ("patients.csv con >=1 encuentro",
                               "SELECT count(DISTINCT PATIENT) FROM syn_encounters"),
        "visit_occurrence": ("encounters.csv", "SELECT count(*) FROM syn_encounters"),
        "condition_occurrence": ("conditions.csv", "SELECT count(*) FROM syn_conditions"),
        "drug_exposure": ("medications.csv", "SELECT count(*) FROM syn_medications"),
        "measurement": ("observations.csv (lab+vitales numéricos)",
                        "SELECT count(*) FROM syn_observations "
                        "WHERE CATEGORY IN ('laboratory','vital-signs') AND TYPE='numeric'"),
    }
    concepto = {"person": "gender_concept_id", "observation_period": None,
                "visit_occurrence": "visit_concept_id",
                "condition_occurrence": "condition_concept_id",
                "drug_exposure": "drug_concept_id", "measurement": "measurement_concept_id"}

    print()
    print("RESUMEN (filas OMOP vs filas Synthea)")
    print(f"  {'tabla OMOP':<22}{'filas OMOP':>12}  {'origen Synthea':<42}{'filas':>10}{'% concept_id=0':>16}")
    print("  " + "-" * 102)
    for t in tablas_omop:
        n = contar(con, t)
        etiqueta, q = origen[t]
        n_src = con.execute(q).fetchone()[0]
        col = concepto[t]
        if col and n > 0:
            ceros = con.execute(f"SELECT count(*) FROM {t} WHERE {col} = 0").fetchone()[0]
            pct = f"{100.0 * ceros / n:.1f} %"
        else:
            pct = "-"
        print(f"  {t:<22}{n:>12,}  {etiqueta:<42}{n_src:>10,}{pct:>16}")

    # 4) Avisos útiles
    sin_periodo = con.execute("""
        SELECT count(*) FROM person p
        WHERE NOT EXISTS (SELECT 1 FROM observation_period op WHERE op.person_id = p.person_id)
    """).fetchone()[0]
    extra = contar(con, "condition_occurrence") - con.execute(
        "SELECT count(*) FROM syn_conditions").fetchone()[0]
    sin_visita = con.execute(
        "SELECT count(*) FROM condition_occurrence WHERE visit_occurrence_id IS NULL").fetchone()[0]
    print()
    print(f"  Personas sin observation_period (sin encuentros): {sin_periodo}")
    print(f"  Filas extra en condition_occurrence por mapeos 1->N ('Maps to' a 2 conceptos): {extra}")
    print(f"  Condiciones sin visita enlazada: {sin_visita}")

    con.close()
    print("\nListo. Ahora ejecuta: python sql/correr_consultas.py")


if __name__ == "__main__":
    main()
