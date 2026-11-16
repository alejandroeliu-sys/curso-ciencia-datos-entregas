"""Pruebas de calidad de la matriz de features (Lab 23)."""
import os
from pathlib import Path

import duckdb
import pandas as pd
import pytest

AQUI = Path(__file__).resolve().parent.parent
CSV = AQUI / "features.csv"
DB = os.environ.get(
    "OMOP_DB", str(Path.home() / "s12-omop-cdm-introduccion" / "omop_20k.duckdb")
)
N_COHORTE = 5372


@pytest.fixture(scope="module")
def df():
    if not CSV.exists():
        pytest.skip("Falta features.csv; corre primero build_features.py")
    return pd.read_csv(CSV, parse_dates=["fecha_indice"])


@pytest.fixture(scope="module")
def con():
    if not Path(DB).exists():
        pytest.skip("No se encontró la base OMOP")
    c = duckdb.connect(DB, read_only=True)
    yield c
    c.close()


# 1. Tamaño de la cohorte
def test_filas_igual_cohorte(df):
    assert len(df) == N_COHORTE
    assert df["person_id"].is_unique


# 2. Ninguna fecha posterior al día 0
def test_sin_fechas_posteriores_al_indice(df, con):
    con.register("f", df[["person_id", "fecha_indice", "albumina_ultima"]])
    discrepantes = con.execute("""
        WITH previas AS (
            SELECT f.person_id, f.albumina_ultima, m.value_as_number,
                   m.measurement_date,
                   MAX(m.measurement_date) OVER (PARTITION BY f.person_id) AS ultima_fecha
            FROM f
            JOIN measurement m
              ON m.person_id = f.person_id
             AND m.measurement_concept_id = 3024561
             AND m.measurement_date BETWEEN f.fecha_indice - INTERVAL 365 DAY
                                        AND f.fecha_indice - INTERVAL 1 DAY
             AND m.value_as_number IS NOT NULL
             WHERE f.albumina_ultima IS NOT NULL
        )
        SELECT person_id
        FROM previas
        WHERE measurement_date = ultima_fecha
        GROUP BY person_id, albumina_ultima
        HAVING SUM(CASE WHEN ABS(value_as_number - albumina_ultima) < 1e-6
                        THEN 1 ELSE 0 END) = 0
    """).df()
    assert discrepantes.empty, f"{len(discrepantes)} personas con albúmina posterior al día 0"
    columnas_fecha = [c for c in df.columns if "fecha" in c and c != "fecha_indice"]
    for c in columnas_fecha:
        assert (pd.to_datetime(df[c]) <= df["fecha_indice"]).all(), c
    assert (df["obs_previa_dias"] >= 0).all()


# 3. Rangos fisiológicos plausibles sin datos faltantes
RANGOS = {
    "edad": (64, 110),
    "albumina_ultima": (1.0, 6.5),
    "egfr_ckdepi2021": (0, 200),
    "pas_ultima": (40, 260),
    "imc_ultimo": (10, 80),
    "estancia_indice_dias": (0, 365),
    "n_ingredientes_365": (0, 100),
}


@pytest.mark.parametrize("col,rango", RANGOS.items())
def test_rangos_fisiologicos(df, col, rango):
    lo, hi = rango
    valores = df[col].dropna()
    assert valores.between(lo, hi).all(), f"{col} fuera de [{lo}, {hi}]"


def test_egfr_nulo_si_creatinina_implausible(df):
    implausible = (df["creatinina_ultima"] < 0.2) | (df["creatinina_ultima"] > 20)
    assert df.loc[implausible, "egfr_ckdepi2021"].isna().all()


# 4. Edad coherente con la fecha de nacimiento
def test_edad_coherente_con_nacimiento(df, con):
    con.register("f2", df[["person_id", "fecha_indice", "edad"]])
    dif = con.execute("""
        SELECT f2.edad - (YEAR(f2.fecha_indice) - p.year_of_birth) AS dif
        FROM f2 JOIN person p USING (person_id)
    """).df()["dif"]
    assert len(dif) == len(df)
    assert dif.between(-1, 0).all()


# 5. Ninguna columna 100% constante ni 100% faltantes
def test_sin_columnas_constantes_ni_vacias(df):
    vacias = [c for c in df.columns if df[c].isna().all()]
    constantes = [c for c in df.columns if df[c].nunique(dropna=True) <= 1]
    assert not vacias, f"100% faltantes: {vacias}"
    assert not constantes, f"Constantes: {constantes}"
