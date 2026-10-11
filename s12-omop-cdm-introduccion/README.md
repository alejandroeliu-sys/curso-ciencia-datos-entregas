# Laboratorio 12 — Primeros pasos en OMOP CDM

Alumno: Alejandro Eliu Cedillo Rivero

## Objetivo
Convertir los datos sintéticos de Synthea del laboratorio 10 al modelo común de datos OMOP CDM v5.4, cargar los vocabularios de ATHENA y revisar la calidad del resultado.

## Datos de origen
- Synthea 4.0, semilla 42, Massachusetts (laboratorio 10).
- Archivos usados: patients.csv, encounters.csv, conditions.csv, medications.csv y observations.csv.

## Actividad 1 — Ruta elegida
Mapeo a mano en SQL (person, observation_period, visit_occurrence y condition_occurrence) con DuckDB, el cual es el mismo motor del laboratorio 10, sin instalar R ni Docker.
Los datos vienen de Synthea 4.0 y ETL-Synthea, el cual revise y parece que va una versión atras; además, escribir el mapeo  obliga a entender cada tabla OMOP.

## Vocabularios (ATHENA)
SNOMED, ICD10CM, RxNorm, LOINC, ATC y UCUM, más los básicos (Gender, Race, Ethnicity, Visit, Type Concept, Domain).

## Estructura de la carpeta
- sql/cargar_vocab.py: carga CONCEPT, CONCEPT_RELATIONSHIP y CONCEPT_ANCESTOR en DuckDB.
- sql/convertir.py: convierte los CSV de Synthea a tablas OMOP.
- sql/consultas_omop.sql: consultas comentadas de las actividades 5 a 8.
- sql/correr_consultas.py: ejecuta las consultas y muestra los resultados.
- sql/eunomia.py: descarga la base de ejemplo Eunomia (GiBleed) para la actividad 10.
- diagrama_omop.md: diagrama entidad-relación (actividad 4).
- reporte_calidad.md: resultados y diagnóstico de calidad.

## Base de datos
El archivo omop.duckdb no se sube a GitHub por su tamaño; se puede regenerar con los scripts de la carpeta sql.

## Avance
- [x] Actividad 1: ruta elegida
- [ ] Actividad 2: conversión y conteos por tabla
- [ ] Actividad 3: vocabularios cargados
- [ ] Actividad 4: diagrama
- [ ] Actividades 5 a 10: consultas y reporte de calidad
