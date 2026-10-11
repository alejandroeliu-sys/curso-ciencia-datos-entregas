# Laboratorio 12 — Nota para Fedora 44 (sin R, sin Docker)

## ¿Hace falta instalar algo más?

**No.** Basta con el venv del Lab 10 (`duckdb` 1.5.x y `pandas`).

- `eunomia.py` descarga con `urllib` y descomprime con `zipfile`, que vienen
  con Python: **no hace falta `requests`**.
- Ningún script necesita `pytz` (las fechas de Synthea se leen como texto y
  se convierten en SQL). Ojo: si tú haces `SELECT` de una columna
  `TIMESTAMP WITH TIME ZONE` desde Python y sale
  `Required module 'pytz' failed to import`, instala `pip install pytz`.
- Para descomprimir el zip de ATHENA puedes usar `unzip` (suele venir en
  Fedora; si no: `sudo dnf install unzip`) o el propio Python (abajo).

## Comandos exactos

```bash
# 1) Carpetas del lab
mkdir -p ~/s12-omop-cdm-introduccion/sql ~/s12-omop-cdm-introduccion/vocab
cd ~/s12-omop-cdm-introduccion
# copia aquí dentro de sql/ los ficheros: cargar_vocab.py, convertir.py,
# consultas_omop.sql, correr_consultas.py, eunomia.py

# 2) Activar el venv del Lab 10 y comprobar versiones
source ~/s10-sql-fundamentals/venv/bin/activate
python -c "import duckdb, pandas; print('duckdb', duckdb.__version__, '| pandas', pandas.__version__)"

# 3) Descomprimir el zip de ATHENA en vocab/ (cambia el nombre del zip)
unzip -o ~/Descargas/vocabulary_download_v5_*.zip -d ~/s12-omop-cdm-introduccion/vocab
#    alternativa sin unzip:
# python -m zipfile -e ~/Descargas/vocabulary_download_v5_XXXX.zip ~/s12-omop-cdm-introduccion/vocab
ls ~/s12-omop-cdm-introduccion/vocab     # debe mostrar CONCEPT.csv, CONCEPT_RELATIONSHIP.csv, ...

# 4) Ejecutar EN ESTE ORDEN (los vocabularios van ANTES de convertir)
python sql/cargar_vocab.py        # vocabularios -> omop.duckdb
python sql/convertir.py           # Synthea -> person, observation_period, visit_occurrence, condition_occurrence (+ opcionales)
python sql/correr_consultas.py    # actividades 5-8 (o: python sql/correr_consultas.py 6)
python sql/eunomia.py             # actividad 10: descarga GiBleed y compara (necesita internet)
```

## Avisos

- Cierra DBeaver / la CLI de DuckDB antes de ejecutar los scripts: DuckDB
  bloquea el fichero `.duckdb` si otro programa lo tiene abierto para escritura.
- Espacio en disco: el zip de ATHENA ocupa entre 1 y varios GB y
  `omop.duckdb` puede crecer a varios GB (sobre todo `concept_relationship` y
  `concept_ancestor`). La carga puede tardar unos minutos.
- Si `cargar_vocab.py` dice que falta un concepto clave (`??`), te faltó
  marcar ese vocabulario en ATHENA (p. ej. Gender, Race, Ethnicity, Visit, Type Concept).
