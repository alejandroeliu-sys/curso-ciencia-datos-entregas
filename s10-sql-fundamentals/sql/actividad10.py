from pathlib import Path
import time
import pandas as pd

csv = Path.home() / "s10-sql-fundamentals" / "synthea" / "output" / "csv"
patients = pd.read_csv(csv / "patients.csv")
conditions = pd.read_csv(csv / "conditions.csv")


def medir(nombre, funcion):
    inicio = time.perf_counter()
    funcion()
    fin = time.perf_counter()
    print(nombre, round(fin - inicio, 3), "segundos")


def pacientes_y_vivos():
    vivos = patients["DEATHDATE"].isna().sum()
    print("pacientes", len(patients), "vivos", int(vivos))


def por_sexo():
    print(patients.groupby("GENDER").size())


def diez_diagnosticos():
    conteo = conditions.groupby("DESCRIPTION").size()
    print(conteo.sort_values(ascending=False).head(10))


medir("1 pacientes y vivos", pacientes_y_vivos)
medir("2 sexo", por_sexo)
medir("3 diez diagnosticos", diez_diagnosticos)
