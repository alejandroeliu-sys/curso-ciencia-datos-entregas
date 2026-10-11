# s13 — Laboratorio 13: Exposición a fármacos y laboratorios

OMOP CDM v5.4: **DRUG_EXPOSURE**, **MEASUREMENT** y tablas derivadas (**DRUG_ERA**, **CONDITION_ERA**, adherencia **PDC/MPR**).

Se trabaja sobre la base creada en el Lab 12: `~/s12-omop-cdm-introduccion/omop.duckdb`.
Todo lo nuevo se guarda en el esquema **`results`** de esa misma base (las tablas OMOP originales no se tocan).

## Contenido

| Fichero | Para qué |
|---|---|
| `sql/farmacoepi.sql` | Todas las consultas, comentadas, separadas por `-- >>> CONSULTA x.y \| ¿pregunta?`. Las marcadas `[CREA ...]` crean tablas en `results`. |
| `sql/correr_farmacoepi.py` | Ejecuta las consultas (todas, una actividad o una consulta) y las imprime como tablas. |
| `laboratorio13.ipynb` | Notebook con tablas y figuras (usa las mismas consultas + `%sql` de jupysql). Guarda los PNG en `figuras/`. |
| `reporte_calidad.md` | Plantilla del reporte de calidad (rellenar los `[[...]]`). |

## Decisiones del laboratorio

* **Ingrediente:** *lisinopril* (IECA). Es frecuente en Synthea, es de **uso crónico** (tiene sentido medir adherencia) y Synthea lo registra como fármaco clínico (*lisinopril 10 MG Oral Tablet*), nunca como ingrediente: perfecto para comparar "concepto exacto" vs "descendientes" (actividad 3).
* **Analito basal:** presión arterial sistólica (LOINC 8480-6), lógico para un antihipertensivo.
* **Normalización de unidades:** caso real (temperatura `Cel` / `[degF]`) + caso **simulado** (30 % de la glucosa LOINC 2339-0 pasada a mmol/L con el factor 18.016 y devuelta a mg/dL).
* **Rangos plausibles:** peso, frecuencia cardiaca y PAS (+ IMC como ejemplo de umbral pensado para adultos).
* Todo está en la consulta **0.1** (`results.parametros`): si quieres otro ingrediente o analito, cámbialo ahí y vuelve a ejecutar.

## Instalación (una sola vez)

Se reutiliza el venv del Lab 10 (Python 3.14, duckdb 1.5.x, pandas 3.0.6). Solo faltan Jupyter, jupysql y matplotlib.
**Escribe los comandos de uno en uno** (pulsa Enter después de cada línea):

```
mkdir -p ~/s13-omop-drug-measurement
cd ~/s13-omop-drug-measurement
python3 -m zipfile -e ~/Descargas/lab13_entrega.zip .
source ~/s10-sql-fundamentals/venv/bin/activate
pip install jupyterlab jupysql matplotlib
python -c "import duckdb, pandas, matplotlib, sql; print(duckdb.__version__, pandas.__version__)"
```

(Si tu carpeta de descargas se llama `Downloads`, cambia `~/Descargas` por `~/Downloads`.)
No hace falta `duckdb-engine` ni `pytz`: el notebook pasa a jupysql la conexión DuckDB directamente.

## Uso

Siempre desde `~/s13-omop-drug-measurement` y con el venv activado:

```
python sql/correr_farmacoepi.py
python sql/correr_farmacoepi.py > salida_farmacoepi.txt
python sql/correr_farmacoepi.py 5
python sql/correr_farmacoepi.py 0 7.2
jupyter nbconvert --to notebook --execute --inplace laboratorio13.ipynb
ls figuras
jupyter lab
```

* La 1.ª línea crea las tablas `results.*` y muestra todo (unos segundos).
* La 2.ª guarda la salida en un fichero para el reporte.
* `5` = solo la actividad 5; `0 7.2` = parámetros + consulta 7.2.
* `nbconvert ... --execute --inplace` ejecuta el notebook entero sin abrirlo y deja las figuras en `figuras/`.
* `jupyter lab` lo abre en el navegador (para salir: Ctrl+C en la terminal y `y`).

Para empezar de cero las tablas derivadas: `python sql/correr_farmacoepi.py --crear` (las recrea) o, en DuckDB, `DROP SCHEMA results CASCADE;`.

## ⚠️ Bloqueo de DuckDB

Un fichero `.duckdb` solo puede tenerlo abierto **en escritura** un programa a la vez. `correr_farmacoepi.py` escribe (crea `results.*`), el notebook solo lee.
Si ves `Could not set lock on file ... omop.duckdb`:

* cierra DBeaver / la CLI de DuckDB,
* en Jupyter: *Kernel → Shut Down Kernel* (o cierra `jupyter lab` con Ctrl+C),
* y vuelve a ejecutar.

## Variables opcionales

| Variable | Por defecto |
|---|---|
| `LAB13_DB` | `~/s12-omop-cdm-introduccion/omop.duckdb` |
| `SYNTHEA_CSV` | `~/s10-sql-fundamentals/synthea/output/csv` (solo para la consulta 9.4, que lee `observations.csv`) |

## Qué NO hace este laboratorio

* **Achilles** y **Data Quality Dashboard (DQD)** de OHDSI, que son las herramientas estándar de caracterización y calidad, necesitan R (y Java/DatabaseConnector); aquí hacemos a mano en SQL una versión reducida de algunas de sus comprobaciones (concepto 0, unidades, rangos plausibles).
* No se crea una tabla OBSERVATION (el ETL del Lab 12 no la generó); la actividad 9 muestra lo que se perdió.
