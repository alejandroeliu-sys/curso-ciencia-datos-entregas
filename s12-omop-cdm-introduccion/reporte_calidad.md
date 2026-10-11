# Reporte de calidad — Laboratorio 12 (OMOP CDM v5.4)

Alumno: Alejandro Eliu Cedillo Rivero

Base: datos sintéticos de Synthea 4.0 (semilla 42, Massachusetts) convertidos a mano a OMOP CDM v5.4 con SQL en DuckDB (`omop.duckdb`, no se sube al repositorio). Las salidas completas de cada script están en `*_resultado.txt`.

---

## Actividad 1 — Ruta elegida

El mapeo a mano se escribio en SQL (person, observation_period, visit_occurrence y condition_occurrence) con DuckDB, el mismo motor del laboratorio 10, sin instalar R ni Docker.
Los datos vienen de Synthea 4.0 y ETL-Synthea que al parecer suele ir una versión atrás. EL mapeo permite entender cada tabla  OMOP.

## Actividad 2 — Conversión

Comandos (dentro de `~/s12-omop-cdm-introduccion`, con el entorno de Python del laboratorio 10):

```bash
source $HOME/s10-sql-fundamentals/venv/bin/activate
python sql/cargar_vocab.py
python sql/convertir.py
```

Versiones: Fedora 44, Python 3.14, duckdb 1.5, pandas 3.0, Synthea 4.0, vocabularios de ATHENA descargados el 9 y 10 de octubre de 2026.

| Tabla OMOP | Filas OMOP | Origen Synthea | Filas origen | % concept_id = 0 |
|---|---:|---|---:|---:|
| person | 5,706 | patients.csv | 5,706 | 0.0 % |
| observation_period | 5,706 | pacientes con al menos un encuentro | 5,706 | — |
| visit_occurrence | 324,239 | encounters.csv | 324,239 | 1.3 % |
| condition_occurrence | 202,868 | conditions.csv | 202,868 | 1.4 % |
| drug_exposure (opcional) | 271,654 | medications.csv | 271,611 | 0.0 % |
| measurement (opcional) | 2,195,630 | observations.csv (laboratorio y signos vitales numéricos) | 2,195,630 | 0.0 % |

- 0 personas sin observation_period, 0 condiciones sin visita enlazada.
- drug_exposure tiene 43 filas más que medications.csv porque algunos medicamentos se traducen a dos conceptos estándar.

Problemas y soluciones:
1. La primera descarga de ATHENA no incluía los vocabularios Gender y Ethnicity (el script avisó que faltaban los conceptos 8507, 8532, 38003563 y 38003564). Pedí una segunda descarga agregando Gender, Race y Ethnicity y quitando RxNorm Extension (que no se necesita para Synthea de EE. UU.), y volví a cargar.


## Actividad 3 — Vocabularios

Vocabularios: SNOMED, ICD10CM, RxNorm, LOINC, ATC y UCUM, más Gender, Race, Ethnicity, Visit, Type Concept y Domain.

| Tabla | Filas |
|---|---:|
| concept | 2,027,724 |
| concept_relationship | 14,132,832 |
| concept_ancestor | 12,075,120 |
| vocabulary | 45 |
| domain | 50 |
| concept_class | 433 |
| relationship | 724 |

- **Total de conceptos: 2,027,724.**
- **Conceptos estándar (standard_concept = 'S'): 847,760 (≈ 42 %).**
- ICD10CM y ATC tienen 0 conceptos estándar: ICD10CM es un vocabulario de origen que se traduce a SNOMED, y ATC es una clasificación de medicamentos (sirve para agrupar, no para registrar).

## Actividad 4 — Diagrama ER

El diagrama está en `diagrama_omop.md` (y la imagen en `diagrama_omop.png`). Comparado con la especificación oficial v5.4, las columnas y tipos son los mismos; las diferencias están en cómo se llenan:

1. **`provider_id`, `care_site_id` y `location_id` quedan en NULL** y no existen las tablas PROVIDER, CARE_SITE ni LOCATION. Es una **simplificación legítima**: en v5.4 esas columnas aceptan NULL; solo se pierde la posibilidad de analizar por hospital o médico.
2. **No hay enrutado por dominio**: todo `conditions.csv` va a `condition_occurrence`, aunque el 51.6 % de esos conceptos es del dominio Observation (empleo, estrés, educación). Esto **no es del todo legítimo**: la convención OMOP dice que cada registro va a la tabla de su dominio (estos deberían ir a OBSERVATION). Es aceptable para un primer laboratorio, pero es un error conocido de mi conversión.

## Actividad 5 — % de concept_id = 0

| Tabla | Campo | Filas | Con 0 | % |
|---|---|---:|---:|---:|
| condition_occurrence | condition_concept_id | 202,868 | 2,859 | 1.41 |
| condition_occurrence | condition_source_concept_id | 202,868 | 0 | 0.00 |
| condition_occurrence | condition_type_concept_id | 202,868 | 0 | 0.00 |
| observation_period | period_type_concept_id | 5,706 | 0 | 0.00 |
| person | gender_concept_id | 5,706 | 0 | 0.00 |
| person | race_concept_id | 5,706 | 76 | 1.33 |
| person | ethnicity_concept_id | 5,706 | 0 | 0.00 |
| visit_occurrence | visit_concept_id | 324,239 | 4,298 | 1.33 |
| visit_occurrence | visit_type_concept_id | 324,239 | 0 | 0.00 |
| drug_exposure | drug_concept_id | 271,654 | 0 | 0.00 |
| measurement | measurement_concept_id | 2,195,630 | 0 | 0.00 |
| measurement | unit_concept_id | 2,195,630 | 274,605 | 12.51 |

**Diagnósticos:**
- Las condiciones sin concepto estándar (1.41 %) son casi todas códigos SNOMED de "antecedentes" (History of tubal ligation, History of coronary artery bypass grafting, History of appendectomy...) y situaciones sociales (Refugee). El código existe en SNOMED (el concepto de origen sí se encontró, 0 % en condition_source_concept_id), pero no tiene un "Maps to" a un concepto estándar. Es una limitación del vocabulario, no un error de la conversión.
- Las visitas con 0 (1.33 %) son las clases de encuentro home, virtual, snf y hospice.
- La raza con 0 (1.33 %) corresponde a la categoría "other" de Synthea, que no tiene concepto estándar.
- El 12.51 % de las mediciones no tiene unidad estándar: el número existe, pero sin unidad cuesta interpretarlo.
- Hallazgo importante: solo el 47.0 % de lo que Synthea llama "condición" es del dominio Condition; el 51.6 % es Observation.

## Actividad 6 — Caracterización de la población

- **Personas:** 5,706.
- **Sexo:** 2,920 mujeres (8532 FEMALE, 51.2 %) y 2,786 hombres (8507 MALE, 48.8 %).
- **Año de nacimiento:** de la década de 1910 a la de 2020; las décadas más pobladas son 1960–2000 (población general, con niños y adultos mayores). Mediana del año de nacimiento: 1982.
- **Mediana de días de observación:** 10,477 días (28.7 años); media 11,254.6; mínimo 0; máximo 40,058.
- **Visitas por persona:** 56.82 (324,239 visitas; las 5,706 personas tienen al menos una).

Visitas por tipo:

| visit_concept_id | Tipo | Visitas | Personas | Visitas por persona con ese tipo | Visitas por persona (total) |
|---|---|---:|---:|---:|---:|
| 9202 | Outpatient Visit | 288,109 | 5,706 | 50.49 | 50.49 |
| 9203 | Emergency Room Visit | 26,625 | 4,454 | 5.98 | 4.67 |
| 9201 | Inpatient Visit | 5,207 | 1,925 | 2.70 | 0.91 |
| 0 | No matching concept | 4,298 | 1,675 | 2.57 | 0.75 |

Top 20 "diagnósticos" por número de personas (`count(DISTINCT person_id)`):

| # | concept_id | concept_name | Dominio | Personas | % personas |
|---:|---|---|---|---:|---:|
| 1 | 4199788 | Medication review due | Observation | 5,706 | 100.0 |
| 2 | 4281516 | Gingivitis | Condition | 4,608 | 80.8 |
| 3 | 4053118 | Full-time employment | Observation | 4,470 | 78.3 |
| 4 | 4251306 | Stress | Observation | 4,468 | 78.3 |
| 5 | 4059634 | Part-time employment | Observation | 3,659 | 64.1 |
| 6 | 40481087 | Viral sinusitis | Condition | 3,615 | 63.4 |
| 7 | 4172829 | Limited social contact | Condition | 3,042 | 53.3 |
| 8 | 4309238 | Social isolation | Condition | 3,040 | 53.3 |
| 9 | 4090111 | Gingival disease | Condition | 2,706 | 47.4 |
| 10 | 4060985 | Body mass index 30+ - obesity | Condition | 2,687 | 47.1 |
| 11 | 42538208 | Not in labor force | Observation | 2,675 | 46.9 |
| 12 | 4076230 | Received higher education | Observation | 2,665 | 46.7 |
| 13 | 4112343 | Acute viral pharyngitis | Condition | 2,502 | 43.8 |
| 14 | 45768458 | Victim of intimate partner abuse | Observation | 2,396 | 42.0 |
| 15 | 40274283 | Primary dental caries | Condition | 2,383 | 41.8 |
| 16 | 260139 | Acute bronchitis | Condition | 2,176 | 38.1 |
| 17 | 37018196 | Prediabetes | Condition | 2,124 | 37.2 |
| 18 | 439777 | Anemia | Condition | 2,016 | 35.3 |
| 19 | 4313322 | Reports of violence in the environment | Observation | 1,882 | 33.0 |
| 20 | 4251171 | Unemployed | Observation | 1,689 | 29.6 |

Nota: la lista mezcla enfermedades con observaciones sociales (empleo, estudios, violencia), por la falta de enrutado por dominio (actividad 4). Un top real de enfermedades debe filtrar `domain_id = 'Condition'`.

## Actividad 7 — Estándar vs origen

Condición elegida: **hipertensión esencial** (concepto estándar 320128, código SNOMED 59621000).

| Método | Personas | Eventos |
|---|---:|---:|
| A) por condition_concept_id (estándar) | 1,259 | 1,259 |
| B) por condition_source_value (código del estándar) | 1,259 | 1,259 |
| C) por condition_source_value (todos los códigos SNOMED con ese nombre) | 1,259 | 1,259 |

**Explicación:** los conteos son iguales porque Synthea ya registra la hipertensión con el mismo código SNOMED que OMOP usa como estándar, así que no hubo traducción (un solo código de origen alimenta al concepto, consulta 7.3). La diferencia aparece en otros casos: cuando el código de origen no es estándar (consulta 7.5, por ejemplo "Non-small cell carcinoma of lung, TNM stage 1" se traduce a 4115276 "Non-small cell lung cancer") o cuando se cuenta por jerarquía con CONCEPT_ANCESTOR (consulta 7.4: además de los 1,259 con hipertensión esencial aparecen 121 personas con 439393 Pre-eclampsia, que también es un trastorno hipertensivo). En datos reales, con códigos locales o ICD-10, contar por código de origen subestima los casos.

## Actividad 8 — Filtro de observation_period

| Eventos totales | Dentro del periodo | Fuera | % diferencia |
|---:|---:|---:|---:|
| 202,868 | 201,578 | 1,290 | 0.64 % |

De los 1,290 eventos fuera, 1,289 (1,044 personas) empiezan exactamente 1 día antes del inicio del periodo y solo 1 queda 15 días después del final. La causa es la zona horaria: Synthea escribe la hora de los encuentros en UTC y la fecha de las condiciones en hora local.

**Implicaciones:**
Si un estudio filtra por observation_period pierde el 0.64 % de los eventos, casi todos por un desfase de un día y no por datos realmente fuera de seguimiento.


## Actividad 9 — Exploración en ATHENA de los 3 conceptos principales

| concept_id | concept_name | Vocabulario (código) | Dominio | ¿Estándar? | Hijos directos | Un código de origen que se mapea a él |
|---|---|---|---|---|---:|---|
| 4199788 | Medication review due | SNOMED (314529007) | Observation | Sí | 0 | Nebraska Lexicon 3102688 |
| 4281516 | Gingivitis | SNOMED (66383009) | Condition | Sí | 35 | Nebraska Lexicon 3125197 "Chronic gingivitis" |
| 4053118 | Full-time employment | SNOMED (160903007) | Observation | Sí | 0 | Nebraska Lexicon 3090449 |

Los hijos directos se contaron en CONCEPT_ANCESTOR con `min_levels_of_separation = 1`. Solo Gingivitis es una enfermedad y tiene subtipos; los otros dos son conceptos finales del dominio Observation.

## Actividad 10 — Comparación con Eunomia (GiBleed, CDM 5.3)

| Indicador | Eunomia GiBleed | Mi Synthea → OMOP |
|---|---:|---:|
| Personas | 2,694 | 5,706 |
| % mujeres (8532 FEMALE) | 51.0 | 51.2 |
| Año de nacimiento (mediana) | 1961 | 1982 |
| Mediana de días de observación | 20,870.5 | 10,477 |
| Periodos de observación sin persona en PERSON | 2,649 | 0 |
| Visitas totales | 1,037 | 324,239 |
| Visitas por persona | 0.38 | 56.82 |
| Eventos de condición | 65,332 | 202,868 |
| Personas con ≥ 1 condición | 2,694 | 5,706 |
| Conceptos de condición distintos | 80 | 276 |
| % condition_concept_id = 0 | 0.0 | 1.41 |
| % visit_concept_id = 0 | 0.0 | 1.33 |

Las consultas de la actividad 6 corrieron sin cambios en las dos bases, esto a mi parecer puede interpretarse como que un mismo código puede servir para bases distintas, lo que es en efecto una gran ventaja de OMOP
Las diferencias reflejan las características propias de cada base: Eunomia es una muestra recortada y curada de adultos (solo visitas hospitalarias, todos en el dominio Condition, aunque con periodos huérfanos), y la aquí generada es una conversión completa de una población general.

## Conclusión

La conversión es buena: todas las tablas tienen las mismas filas que su origen y menos del 1.5 % de concept_id = 0 en las tablas clínicas. Se tiene que mejorar el mapeo de las visitas home, virtual, snf y hospice, y las unidades faltantes en measurement.
