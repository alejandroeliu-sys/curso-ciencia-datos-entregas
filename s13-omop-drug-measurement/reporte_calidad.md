# Reporte de calidad — Laboratorio 13
## Exposición a fármacos y laboratorios (OMOP CDM v5.4)

**Alumno:** Alejandro Eliu Cedillo Rivero  **Fecha de ejecución:** 10 de octubre de 2026
**Base:** `/home/alecedillo/s12-omop-cdm-introduccion/omop.duckdb` (ETL propio del Lab 12, Synthea v4.0, semilla 42, Massachusetts)
**Carpeta del laboratorio:** `~/s13-omop-drug-measurement`
**Vocabulario:** ATHENA (SNOMED, ICD10CM, RxNorm, LOINC, ATC, UCUM, Gender, Race, Ethnicity, Visit, Type Concept, Domain; **sin RxNorm Extension**). Tiene 2,027,724 conceptos, de los que 847,760 son estándar, y 12,075,120 filas en `concept_ancestor`.
**Herramientas:** DuckDB 1.5.x, Python 3.14, pandas 3.0.6, jupysql y matplotlib. Las versiones exactas no salen en la salida del script; son las que indicó el alumno.
**Ejecución:** `python sql/correr_farmacoepi.py`: 43 consultas, 0 errores.
**Tablas derivadas:** esquema `results` dentro de la misma `omop.duckdb`.

> Todos los números de este reporte salen de la salida de `correr_farmacoepi.py`; entre paréntesis se indica la consulta. Cuando un dato no aparece en la salida, se dice explícitamente. Las figuras (`figuras/*.png`) salen del notebook y no forman parte de esta salida.

---

## 0. Punto de partida

| Tabla | Filas | % concept_id = 0 |
|---|---:|---:|
| person | 5,706 | — |
| visit_occurrence | 324,239 | — |
| condition_occurrence | 202,868 | 1.41 % (2,859 filas, consulta 9.1) |
| drug_exposure | 271,654 (medications.csv: 271,611) | 0 % |
| measurement | 2,195,630 | 0 % (`unit_concept_id = 0`: 12.51 %) |

No existen las tablas `observation`, `drug_era` ni `condition_era` del ETL.

**Parámetros elegidos (consulta 0.1):**

| Parámetro | Valor |
|---|---|
| Ingrediente | **lisinopril**, concept_id **1308216** (RxNorm, Ingredient) |
| Analito basal | **Systolic blood pressure**, concept_id **3004249** (LOINC 8480-6) |
| Glucosa (actividad 7) | **Glucose [Mass/volume] in Blood**, concept_id **3000483** (LOINC 2339-0) |
| Ventana de persistencia (eras) | 30 días |
| Seguimiento para el PDC | 365 días |
| Ventana para el valor basal | ±90 días |

**Por qué lisinopril:** es un IECA (inhibidor de la enzima convertidora de angiotensina) que se toma de forma **crónica**, así que tiene sentido medir eras largas y adherencia. Es el 11.º ingrediente por número de pacientes (926). Además, Synthea lo registra siempre como **fármaco clínico** (*lisinopril 10 MG Oral Tablet*…) y nunca como ingrediente, lo que hace visible la diferencia de la actividad 3.

---

## 1. Tipo de exposición: `drug_type_concept_id` (consulta 1.1)

| drug_type_concept_id | Nombre | Registros | Personas | % |
|---|---|---:|---:|---:|
| 32817 | EHR | 271,654 | 5,577 | 100.0 |

5,577 de las 5,706 personas (97.7 %) tienen al menos un registro de fármaco.

**Interpretación:** todos los registros llevan el tipo genérico *EHR* (32817) porque el ETL lo fijó así. Por su origen, `medications.csv` de Synthea contiene **prescripciones** (órdenes del médico), no dispensaciones de farmacia ni administraciones. Esto implica que:
* una prescripción no garantiza que el paciente retirara el fármaco ni que lo tomara. El PDC y el MPR de la §5 miden **cobertura prescrita**, no adherencia real; la literatura de adherencia usa dispensaciones o reclamaciones de farmacia;
* sería más preciso un Type Concept de prescripción de EHR (p. ej. "EHR prescription"; hay que verificar su concept_id en ATHENA);
* algunos registros parecen en realidad **administraciones** de un día (epoetina, cisplatino, paclitaxel; §2), que se distinguirían con un tipo de administración.

## 2. Caracterización de DRUG_EXPOSURE: completitud de fechas (consultas 2.1–2.6)

**Top 20 ingredientes**, subiendo por `concept_ancestor` hasta `concept_class_id = 'Ingredient'` (2.1):

| # | Ingrediente (concept_id) | Personas | Registros | Productos distintos |
|---|---|---:|---:|---:|
| 1 | sodium fluoride (19069022) | 4,832 | 15,191 | 1 |
| 2 | acetaminophen (1125315) | 3,587 | 19,593 | 12 |
| 3 | amoxicillin (1713332) | 1,604 | 1,932 | 5 |
| 4 | ibuprofen (1177480) | 1,446 | 5,292 | 3 |
| 5 | clavulanate (1759842) | 1,188 | 1,320 | 3 |
| 6 | simvastatin (1539403) | 1,146 | 5,813 | 5 |
| 7 | naproxen (1115008) | 1,131 | 1,239 | 2 |
| 8 | ethinyl estradiol (1549786) | 1,020 | 2,229 | 8 |
| 9 | nitroglycerin (1361711) | 958 | 1,005 | 2 |
| 10 | metoprolol (1307046) | 936 | 1,003 | 8 |
| 11 | **lisinopril (1308216)** | **926** | **24,334** | 9 |
| 12 | inert ingredients (19127890) | 898 | 1,869 | 6 |
| 13 | levonorgestrel (1589505) | 869 | 1,447 | 6 |
| 14 | clopidogrel (1322184) | 810 | 830 | 2 |
| 15 | norethindrone (1521369) | 726 | 1,557 | 5 |
| 16 | hydrochlorothiazide (974166) | 722 | 19,190 | 13 |
| 17 | penicillin V (1729720) | 715 | 787 | 2 |
| 18 | hydrocodone (1174888) | 691 | 6,245 | 4 |
| 19 | doxylamine (738818) | 656 | 693 | 1 |
| 20 | dextromethorphan (1119510) | 656 | 693 | 1 |

Cómo leer la tabla:
* Un producto combinado suma en **cada** uno de sus ingredientes. Amoxicilina/clavulánico explica *clavulanate*; los anticonceptivos explican *ethinyl estradiol*, *levonorgestrel* y *norethindrone*; un antitusivo combinado explica *doxylamine* y *dextromethorphan*, que tienen cifras idénticas (656 / 693).
* *Inert ingredients* (898 personas) corresponde a las pastillas placebo de los envases de anticonceptivos. No es un fármaco activo y conviene excluirlo de los análisis clínicos.
* Lisinopril y la hidroclorotiazida tienen muchos registros por persona (≈ 26 por persona): son tratamientos crónicos con renovaciones frecuentes.

**`days_supply`** (2.2): **100 % NULL** (271,654 filas).

**Duración según las fechas** (2.3): duración = `drug_exposure_end_date − drug_exposure_start_date`.

| Origen de la fecha fin | Duración | Registros | Personas | % |
|---|---|---:|---:|---:|
| con STOP en Synthea | 0 días | 92,004 | 4,975 | 33.87 |
| con STOP en Synthea | 1–7 (*) | 45,657 | 1,692 | 16.81 |
| con STOP en Synthea | 8–30 | 35,969 | 4,177 | 13.24 |
| con STOP en Synthea | 31–90 | 20,181 | 2,008 | 7.43 |
| con STOP en Synthea | 91–365 | 26,628 | 3,249 | 9.80 |
| con STOP en Synthea | > 365 | 36,330 | 2,565 | 13.37 |
| sin STOP en Synthea (fin = inicio) | 0 días | 14,885 | 3,849 | 5.48 |

(*) Error de la consulta, ya corregido en el fichero: las duraciones **negativas** (end < start, 0.08 %) se contaban dentro de "1–7". Ver §12.

**Completitud y calidad** (2.4 y 2.6):

| Indicador | Valor |
|---|---:|
| `days_supply` nulo | 100.0 % |
| `quantity` nulo | 0.0 % |
| `drug_exposure_end_date` nulo | 0.0 % |
| `end_date = start_date` | 39.35 % |
| de ellos, sin STOP en Synthea (fin rellenado por el ETL) | 5.48 % del total |
| `end_date < start_date` | 0.08 % (≈ 217 filas, calculado a partir del porcentaje redondeado) |
| `drug_concept_id = 0` | 0.0 % |
| Códigos fuente con más de un drug_concept_id (2.6) | 1 código: RxNorm **235389** *mestranol / norethynodrel* → 2 conceptos (mestranol, norethynodrel), 86 filas |

**Las 43 filas extra frente a `medications.csv`** (2.6): el código 235389 (*mestranol / norethynodrel*) tiene en ATHENA un 'Maps to' a **dos** conceptos estándar, uno por ingrediente. Cada fila de origen se duplicó: 43 filas originales × 2 = **86 filas** en DRUG_EXPOSURE, es decir, **43 filas extra**. Eso cuadra exactamente con 271,654 − 271,611 = 43. No es un error, es el comportamiento que pide THEMIS para mapeos 1→N (una fila por concepto estándar). Hay que tenerlo en cuenta al contar "recetas": esas 43 recetas cuentan dos veces.

**Productos con fin = inicio** (2.5):
* (a) **Administraciones de un día**, con STOP = START en Synthea: epoetina alfa 41,193 filas (151 personas), flúor tópico 15,191 (4,832), cisplatino 9,765, paclitaxel 9,008, tropicamida 3,487, furosemida inyectable 2,278, etc.
* (b) **Recetas crónicas sin STOP**: la última receta de cada tratamiento todavía activo, como lisinopril 10 MG (842), nitroglicerina (908), metoprolol (893), simvastatina 20 MG (821) o clopidogrel (791).

**Diagnóstico:** `days_supply` está vacío porque Synthea no lo trae, y THEMIS indica no inventarlo. La duración hay que sacarla de las fechas. El 39.35 % de filas con fin = inicio mezcla dos cosas distintas: administraciones reales de un día y recetas abiertas en las que el ETL copió la fecha de inicio (duración artificial de 0 días). Para eras y PDC, a estas últimas se les imputa fin = inicio + 29 días (§4).

## 3. Comparación ingrediente vs producto (consultas 3.1–3.2)

| Método | Personas | Registros |
|---|---:|---:|
| A) `drug_concept_id = 1308216` (ingrediente exacto) | **0** | 0 |
| B) descendientes de 1308216 vía `concept_ancestor` | **926** | 24,334 |

Productos que aportan pacientes (3.2). Todos son *Clinical Drug* a **2 niveles** del ingrediente:

| Producto (concept_id) | Personas | Registros |
|---|---:|---:|
| lisinopril 10 MG Oral Tablet (19080128) | 843 | 23,679 |
| lisinopril 20 MG Oral Tablet (19080129) | 68 | 605 |
| lisinopril 5 MG Oral Tablet (1308251) | 21 | 21 |
| hydrochlorothiazide 12.5 MG / lisinopril 20 MG (974200) | 7 | 7 |
| hydrochlorothiazide 12.5 MG / lisinopril 10 MG (974199) | 6 | 6 |
| hydrochlorothiazide 25 MG / lisinopril 20 MG (974201) | 5 | 5 |
| lisinopril 40 MG Oral Tablet (1308221) | 5 | 5 |
| lisinopril 2.5 MG Oral Tablet (1308250) | 5 | 5 |
| lisinopril 30 MG Oral Tablet (19029027) | 1 | 1 |

**Conclusión:** buscar por el concept_id del ingrediente no encuentra a **nadie**, porque los datos están guardados al nivel de producto (dosis + forma farmacéutica). Siempre hay que usar la jerarquía (`concept_ancestor`). La vía B también recoge los combinados con hidroclorotiazida, que una búsqueda por nombre "lisinopril 10 MG" no habría encontrado.

## 4. DRUG_ERA hecha a mano: comparación y justificación (consultas 4.1–4.7)

Algoritmo (*gaps and islands*):
1. Fecha fin efectiva. Si había STOP, los días cubiertos son STOP − inicio (en Synthea el STOP de una receta coincide con el START de la siguiente). Si no había STOP, se imputa inicio + 29 días (THEMIS, receta escrita sin fecha fin).
2. Se fusionan las exposiciones solapadas o contiguas en "tramos de cobertura".
3. Se unen los tramos separados por ≤ 30 días (ventana de persistencia estándar de OHDSI) para formar eras. `gap_days` = días de la era sin cobertura.

| Indicador | Valor |
|---|---:|
| Registros de lisinopril (3.1) | 24,334 |
| Exposiciones tras quitar duplicados exactos (4.1) | 24,010 (se colapsaron 324 filas idénticas en paciente, inicio y duración) |
| Exposiciones con fin imputado (sin STOP) | 950 (4.0 %) |
| Mediana de días por exposición | 28 |
| Tramos sin huecos (4.2) | 942 |
| Eras con ventana de 30 días (4.3) | 942 |
| Personas | 926 |
| Eras por persona | 1.02 |
| Mediana de duración de la era | 3,617.5 días (≈ 9.9 años) |
| Total gap_days | 0 |

Duración de las eras (4.4): ≤ 30 días: 98; 31–90 días: 4; 91–365 días: 11; 1–5 años: 126; > 5 años: **703**.

DRUG_ERA completa para **todos** los ingredientes (4.6): **65,562 eras**, 5,577 personas, 210 ingredientes.

**Comparación y justificación:**
* La base **no tenía** DRUG_ERA del ETL (4.5): las únicas `drug_era` y `condition_era` que aparecen están en el esquema `results` y las creamos en este laboratorio. Lo normal es que la DRUG_ERA la generen los scripts de OHDSI después del ETL, y el ETL del Lab 12 no los incluía. Por eso se construyó a mano.
* Control interno (4.7): la era del lisinopril calculada sola coincide exactamente con la que sale de la DRUG_ERA completa (942 = 942 eras; 926 = 926 personas). Los dos caminos del algoritmo son coherentes.
* **Tramos = eras (942) y gap_days = 0.** La ventana de 30 días no ha unido nada: Synthea renueva las recetas sin dejar huecos. En datos reales la ventana sí fusionaría tramos separados por olvidos o retrasos en la recogida. Esto es una propiedad de los datos sintéticos, no un error.
* Las 98 eras de ≤ 30 días corresponden a pacientes con una sola receta abierta (30 días imputados).

## 5. PDC vs MPR, con supuestos (consultas 5.1–5.4)

**Definición usada:**
* Fecha índice = primera exposición a lisinopril.
* Ventana = 365 días desde la fecha índice, recortada al fin del `observation_period`.
* Elegible = ventana ≥ 91 días. Criterio PQA adicional: ≥ 2 recetas en fechas distintas.

Población (5.1): 926 pacientes, de los que **912** son elegibles y **301** cumplen además el criterio PQA.

| Población | n | PDC p10 | PDC p25 | Mediana | Media | % PDC ≥ 0.8 |
|---|---:|---:|---:|---:|---:|---:|
| a) ventana ≥ 91 días | 912 | 0.99 | 1.0 | 1.0 | 0.914 | **90.2 %** |
| b) + ≥ 2 recetas (PQA) | 301 | 1.00 | 1.0 | 1.0 | 0.984 | **97.3 %** |

MPR (5.3), sobre los 912 elegibles: media 1.018, máximo **2.014**, **821 pacientes con MPR > 1**, PDC máximo 1.0. Con MPR ≥ 0.8 son adherentes el 90.4 %.

Exclusiones (5.4):

| Motivo | Personas | PDC medio |
|---|---:|---:|
| ventana < 91 días | 14 | 0.966 |
| elegible, pero 1 sola receta en el año (fuera del criterio PQA) | 611 | 0.880 |
| elegible también con criterio PQA | 301 | 0.984 |

**PDC vs MPR**
* **PDC (Proportion of Days Covered)** = días *distintos* de la ventana con fármaco disponible / días de la ventana. Cada día cuenta una sola vez, así que **nunca supera 1** (máximo observado: 1.0). Es la métrica de la Pharmacy Quality Alliance (PQA), con umbral de adherencia **≥ 80 %**. Los IECA como el lisinopril entran en su medida *PDC-RASA*.
* **MPR (Medication Possession Ratio)** = suma de días suministrados / días de la ventana. Si las recetas se solapan, o la última se extiende más allá del final de la ventana, **supera 1**: aquí lo hace en 821 de 912 pacientes, con un máximo de 2.014. El 2.014 equivale a dos recetas de ~1 año dentro de la misma ventana (735 días / 365). Por eso el MPR sobreestima la adherencia y se trunca a 1 o se prefiere el PDC.
* Con el criterio PQA, 611 de 912 pacientes (67 %) quedan fuera aunque estén cubiertos: Synthea emite a menudo **una sola receta larga** al año, y la regla de "≥ 2 recetas" está pensada para dispensaciones mensuales de farmacia.

**Supuestos:**
1. Son prescripciones, no dispensaciones.
2. Fin imputado = inicio + 29 cuando falta el STOP. Si se asumiera tratamiento hasta el final del periodo de observación, el PDC subiría.
3. No hay `days_supply`; la cobertura sale de las fechas, con el STOP como día exclusivo.
4. No se acumula stock entre recetas solapadas: el PDC cuenta días, no pastillas.
5. Se eliminan duplicados exactos.

**Lectura:** el 90.2 % de adherencia no es un resultado clínico. Synthea simula renovaciones regulares y por eso el PDC sale casi siempre 1.0. Los pacientes por debajo de 0.8 son, sobre todo, los que tienen una única receta abierta con 30 días imputados.

## 6. Caracterización de MEASUREMENT (consultas 6.1–6.5)

**Top 15 analitos** (6.1):

| # | Analito (concept_id) | Mediciones | Personas | Nº unidades |
|---|---|---:|---:|---:|
| 1 | Pain severity 0-10 [Score] (43055141) | 132,560 | 5,706 | 1 |
| 2 | Systolic blood pressure (3004249) | 80,109 | 5,706 | 1 |
| 3 | Diastolic blood pressure (3012888) | 80,109 | 5,706 | 1 |
| 4 | Body weight (3025315) | 76,445 | 5,706 | 1 |
| 5 | Heart rate (3027018) | 74,894 | 5,706 | 1 |
| 6 | Respiratory rate (3024171) | 74,894 | 5,706 | 1 |
| 7 | Body height (3036277) | 73,247 | 5,706 | 1 |
| 8 | Body mass index (BMI) [Ratio] (3038553) | 67,737 | 5,575 | 1 |
| 9 | Glomerular filtration rate, MDRD/1.73 sq M (46236952) | 54,481 | 1,598 | 2 |
| 10 | Weight difference pre-post dialysis (44786664) | 50,536 | 176 | 1 |
| 11 | Glucose [Mass/volume] in Blood (3000483) | 48,131 | 2,526 | 1 |
| 12 | Calcium [Mass/volume] in Blood (3032503) | 48,131 | 2,526 | 1 |
| 13 | Urea nitrogen [Mass/volume] in Blood (3004295) | 48,131 | 2,526 | 1 |
| 14 | Sodium [Moles/volume] in Blood (3000285) | 48,131 | 2,526 | 1 |
| 15 | Carbon dioxide, total [Moles/volume] in Blood (3014094) | 48,131 | 2,526 | 1 |

Las cifras idénticas (48,131 / 2,526) corresponden a un panel metabólico: todos sus analitos se piden juntos.

| Indicador (6.4) | Valor |
|---|---:|
| Mediciones | 2,195,630 |
| `value_as_number` nulo | 0.0 % |
| `operator_concept_id` no nulo | 0.0 % |
| `value_as_concept_id` no nulo | 0.0 % |
| `unit_concept_id = 0` | **12.51 %** |
| `measurement_concept_id = 0` | 0.0 % |

**Unidades de la glucosa** (6.2): una sola, `mg/dL` → 8840 *milligram per deciliter* (48,131 mediciones, 2,526 personas).

**Unidades fuente que se quedaron sin concepto** (6.5, las 10 primeras):

| Unidad fuente | Mediciones | Ejemplo de analito |
|---|---:|---|
| `{score}` | 132,560 | Pain severity |
| `U/L` | 53,211 | LDH, ALT, AST, ALP… (5 analitos) |
| `mL/min/{1.73_m2}` | 36,899 | Filtrado glomerular (MDRD) |
| `{nominal}` | 33,854 | Densidad de orina |
| `kU/L` | 6,210 | IgE específicas (15 analitos) |
| `{presence}` | 5,103 | Proteína en orina (7 analitos) |
| `[pH]` | 3,241 | pH (3 analitos) |
| `{INR}` | 2,563 | INR |
| `{SG}` | 729 | Densidad de orina |
| `m[IU]/L` | 208 | TSH |

**Interpretación:**
* El 0 % de nulos y de operadores no significa "calidad perfecta": el ETL solo cargó observaciones **numéricas**, y Synthea no genera resultados del tipo "< 5".
* El 12.51 % de `unit_concept_id = 0` tiene dos causas distintas:
  * **(a) Unidades anotadas de UCUM** (`{score}`, `{nominal}`, `{presence}`, `{INR}`, `{SG}`): ≈ 6.0 % solo `{score}`. No existen tal cual como concepto estándar.
  * **(b) Un problema de nuestro ETL** (§12): el Lab 12 busca la unidad comparando el texto exacto con `concept_code` de UCUM, pero ATHENA escribe varias unidades con otra notación. *unit per liter* (8645) tiene el código `[U]/L`, no `U/L`; *kilounit per liter* (8810), `10*3.[U]/L`; *milli-international unit per liter* (9040), `10*-3.[iU]/L`. Comprobado en el extracto de ATHENA de Eunomia; hay que confirmarlo en su base. Solo `U/L`, `kU/L`, `m[IU]/L` y `mL/min/{1.73_m2}` suman 96,528 filas (≈ 4.4 % de MEASUREMENT) que **sí tienen concepto** y no se mapearon.

## 7. Unidades encontradas y normalización (consultas 6.3, 7.0–7.3)

**Analitos con más de una unidad** (6.3 / 7.0):

| Analito | Unidad (n, min–mediana–max) | Unidad (n, min–mediana–max) | Situación |
|---|---|---|---|
| Body temperature | `Cel` (6,297; 36.1–37.8–42.2) | `[degF]` (1; 101.9) | Unidad realmente distinta → **convertir** |
| ALT / AST / ALP | `U/L` (17,285 c/u) | `[iU]/L` (12 c/u) | Unidades **equivalentes** (1 U/L = 1 IU/L): solo unificar la etiqueta. Los 12 valores `[iU]/L` de ALT/AST son altos (101.8–195.0): parecen otro subgrupo clínico, no otro factor |
| Troponina I (alta sensibilidad) | `pg/mL` (2,349; 0–0–348.4) | `ng/L` (191; 0.4–59–119.6) | Equivalentes (1 pg/mL = 1 ng/L) |
| pH de orina | `pH` (33,854) | `[pH]` (729) | Misma unidad con otra escritura |
| Densidad de orina | `{nominal}` (33,854) | `{SG}` (729) | Adimensional; todos los valores son 1.0 (sospechoso, típico de Synthea) |
| Globulina | `g/L` (12,702; **2.0–2.8–3.5**) | `g/dL` (12; 2.4–3.25–3.9) | **Etiqueta incoherente**: 2–3.5 son valores típicos en g/dL (en g/L serían 20–35). No convertir; marcar |
| RDW (3019897) | `fL` (13,900; 39–46) | `%` (4,566; 12.3–15.4) | **Dos magnitudes distintas** (RDW-SD y RDW-CV) bajo el mismo código: no se pueden convertir entre sí |
| Filtrado glomerular MDRD (46236952) | `mL/min/{1.73_m2}` (36,899; mediana 53.0) | `mL/min` (17,582; mediana 19.8) | Sospechoso: el MDRD siempre va normalizado a 1.73 m²; `mL/min` sin normalizar no se convierte sin la superficie corporal. Revisar; no convertir |

**Normalización aplicada** (7.1–7.2):

| Caso | Unidad original | Convertido | Filas | Personas | Media original | Media normalizada |
|---|---|---|---:|---:|---:|---:|
| Temperatura (real) | `[degF]` | sí | 1 | 1 | 101.90 °F | **38.80 °C** |
| Temperatura (real) | `Cel` | no | 6,297 | 3,243 | 38.24 | 38.24 |
| Glucosa (simulada) | `mmol/L` | sí | 14,473 | 2,251 | 4.90 | **88.25 mg/dL** |
| Glucosa | `mg/dL` | no | 33,658 | 2,489 | 88.20 | 88.20 |

* Glucosa simulada: 14,473 de 48,131 mediciones (30.1 %) se pasaron a propósito a mmol/L (valores 3.55–11.09, media 4.9) y luego se devolvieron a mg/dL.
* Reglas usadas: °C = (°F − 32) / 1.8 (NIST SP 811), así que 101.9 °F = 38.8 °C. Glucosa: mg/dL = mmol/L × 18.016 (masa molar 180.16 g/mol, PubChem CID 5793).
* Se conservan `value_original`, `unit_original` y `unit_concept_id_original`.
* Comprobación de ida y vuelta (7.3): diferencia máxima 0.1 mg/dL y media 0.044 mg/dL en las 14,473 filas convertidas (solo redondeo); 0.0 en las no convertidas.
* La figura antes/después está en `figuras/03_normalizacion_glucosa.png`.

## 8. Valores implausibles con criterio citado (consultas 8.1–8.4)

| Analito (LOINC, concept_id) | Unidad | Rango usado | Fuente | Alternativa |
|---|---|---|---|---|
| Peso corporal (29463-7, 3025315) | kg | 2 – 500 | OHDSI DQD v1.4.1 | — |
| Frecuencia cardiaca (8867-4, 3027018) | /min | 10 – 500 | OHDSI DQD v1.4.1 | MIMIC-IV: > 0 y < 300 |
| PA sistólica (8480-6, 3004249) | mm[Hg] | 10 – 250 | OHDSI DQD v1.4.1 | MIMIC-IV: > 0 y < 400 |
| IMC (39156-5, 3038553), extra | kg/m2 | 16 – 100 | OHDSI DQD v1.4.1 | — (umbral pensado para adultos) |

Resultados (8.2):

| Analito | Grupo | Mediciones | < bajo | > alto | % fuera | Personas fuera | Fuera (alternativa MIMIC) |
|---|---|---:|---:|---:|---:|---:|---:|
| IMC | < 18 años | 13,016 | 2,925 | 0 | **22.47** | 634 | — |
| IMC | ≥ 18 años | 54,721 | 0 | 0 | 0.00 | 0 | — |
| Peso | < 18 años | 18,733 | 0 | 0 | 0.00 | 0 | — |
| Peso | ≥ 18 años | 57,712 | 0 | 0 | 0.00 | 0 | — |
| Frecuencia cardiaca | < 18 años | 18,509 | 0 | 0 | 0.00 | 0 | 0 |
| Frecuencia cardiaca | ≥ 18 años | 56,385 | 0 | 0 | 0.00 | 0 | 0 |
| PA sistólica | < 18 años | 18,791 | 0 | 0 | 0.00 | 0 | 0 |
| PA sistólica | ≥ 18 años | 61,318 | 0 | 0 | 0.00 | 0 | 0 |

**Centinelas (8.3):** ninguno. Los 5 valores más repetidos de cada analito son valores fisiológicos normales:
* IMC: 27.8, 27.7, 27.5, 30.1, 27.9, cada uno entre el 3.3 % y el 4.4 %.
* Peso: 81.7, 93.0, 85.9, 72.7, 76.7 kg, ≤ 0.6 % cada uno.
* Frecuencia cardiaca: 98, 62, 76, 82, 70.
* PAS: 118, 116, 114, 117, 119.

Ninguno está fuera de rango ni es 0, −1, 999 o 9999. 8.4 marca 0 posibles centinelas.

**Decisión:** **marcar** (`results.measurement_plausibilidad.fuera_rango`, `posible_centinela`) en vez de borrar o poner a NULL. Así se conserva el dato y cada análisis decide si lo excluye. Solo hay 2,925 mediciones marcadas, todas de IMC < 16 en **menores** y ninguna en adultos (8.4). No son errores: el umbral DQD está pensado para adultos, y en niños el IMC se valora con percentiles por edad y sexo (la base tiene ese concepto, 40762638, con 14,594 mediciones). Un centinela confirmado (un código de "sin dato") sí se trataría como NULL en el análisis.

## 9. Ubicación según THEMIS: MEASUREMENT vs OBSERVATION (consultas 9.1–9.4)

**Dominio de los conceptos en cada tabla** (9.1):

| Tabla | Dominio del concepto | Registros | % de la tabla | Personas |
|---|---|---:|---:|---:|
| condition_occurrence | Observation | **104,724** | **51.6 %** | 5,706 |
| condition_occurrence | Condition | 95,284 | 47.0 % | 5,620 |
| condition_occurrence | (concepto 0) | 2,859 | 1.4 % | 2,127 |
| condition_occurrence | Measurement | 1 | 0.0 % | 1 |
| drug_exposure | Drug | 271,654 | 100 % | 5,577 |
| measurement | Measurement | 2,195,630 | 100 % | 5,706 |

**Casos concretos** (9.2–9.4):

| Dato | Dónde está en nuestra base | Dominio del concepto en su ATHENA | Dónde debería ir |
|---|---|---|---|
| Peso corporal (LOINC 29463-7 → 3025315) | MEASUREMENT (76,445 filas, 5,706 personas) | Measurement | MEASUREMENT ✔ |
| "Tobacco smoking status" (LOINC 72166-2 → 43054909, respuesta en texto) | **no cargado**: 72,965 registros en observations.csv (Never smoked 55,473 / 4,551 pacientes; Ex-smoker 17,198 / 1,236; Smokes tobacco daily 294 / 126) | Observation | OBSERVATION, con la respuesta en `value_as_concept_id` |
| "Body mass index 30+ - obesity" (4060985) | CONDITION_OCCURRENCE (2,687 personas) | **Condition** | CONDITION_OCCURRENCE ✔ |
| "Body mass index 40+ - severely obese" (4256640) | CONDITION_OCCURRENCE (27) | Condition | CONDITION_OCCURRENCE ✔ |
| "Smokes tobacco daily" (SNOMED 449868002 → 42709996) | No aparece en la búsqueda por nombre de 9.2 (ver nota) | Observation, y **no estándar** en su ATHENA | OBSERVATION, usando el concepto estándar al que haga 'Maps to' |
| 104,724 filas de condition_occurrence con dominio Observation | CONDITION_OCCURRENCE | Observation | OBSERVATION |

Notas:
* En su ATHENA, las respuestas *Never smoked tobacco* (4144272), *Ex-smoker* (4310250) y *Smokes tobacco daily* (42709996) son **no estándar** (9.3). Para `value_as_concept_id` habría que seguir su 'Maps to' hasta el concepto estándar.
* La salida no permite saber adónde fue el código 449868002 en condition_occurrence. La búsqueda por nombre de 9.2 no lo encontró; puede haberse mapeado a un concepto con otro nombre o a 0. La consulta 9.2 ya se amplió para buscarlo también por código fuente (§12).
* Las condiciones con dominio Observation más frecuentes que se ven en 11.2 son hallazgos sociales y administrativos: *Medication review due*, *Full-time employment*, *Stress*, *Social isolation*…

**Convención THEMIS:** *"Only records where the source value maps to a CONCEPT_ID in the 'Measurement' domain should be included in this table."* Es decir, lo que decide la tabla es el **dominio del concepto estándar**, no el fichero de origen. La documentación del CDM v5.4 dice además que OBSERVATION recoge los hechos sin prueba estandarizada (hábitos, situación social, antecedentes) y MEASUREMENT los resultados de pruebas estandarizadas. `value_as_number` y `value_as_concept_id` no son excluyentes.

**Conclusión:** MEASUREMENT está bien (100 % dominio Measurement). La gran desviación está en CONDITION_OCCURRENCE: **más de la mitad (51.6 %) de sus filas son de dominio Observation** y deberían estar en una tabla OBSERVATION. El ETL eligió la tabla por fichero (conditions.csv → CONDITION_OCCURRENCE) y no por dominio. Además, el tabaquismo (72,965 registros) se perdió por completo.

## 10. Fecha índice y % con valor basal (consultas 10.1–10.3)

Fecha índice = primera exposición a lisinopril. Basal = PAS más cercana en ±90 días (si hay empate, la anterior). Como definición estricta, se usa solo la previa (−90 a 0 días).

| Indicador | Valor |
|---|---:|
| Pacientes con fecha índice | 926 |
| Fecha índice dentro del observation_period | 926 (100 %) |
| Con PAS basal en ±90 días | 340 (**36.7 %**) |
| Con PAS basal solo previa (−90..0) | 263 (**28.4 %**) |
| Sin basal en ±90 días | 586 (63.3 %) |
| Mediana de PAS basal (±90) | **141.0 mm Hg** |
| Mediana de días entre índice y medición | 0 (el mismo día) |

Distancia a la fecha índice (10.3): −90 a −31 días: 14; −30 a −1: 12; **mismo día: 237**; +1 a +30: 33; +31 a +90: 44; sin basal: 586.

**Interpretación:**
* Cuando hay basal, casi siempre se midió en la **misma visita** en que se prescribió el lisinopril (237 de 340). Es lógico: el médico mide la tensión y prescribe.
* La mediana de 141 mm Hg es compatible con hipertensión (≥ 140, estadio 2 según ACC/AHA 2017), coherente con la indicación.
* La ventana ±90 incluye 77 mediciones **posteriores** al inicio del tratamiento (33 + 44), que ya pueden estar influidas por el fármaco. La definición "solo previa" es la correcta para un basal, a cambio de quedarse con el 28.4 %.
* El 63 % sin basal es bajo para un estudio: muestra que un valor basal hay que comprobarlo, no darlo por supuesto.

## 11. Extra: CONDITION_ERA (consultas 11.1–11.2)

Hay **184,415 eras** a partir de 200,009 condiciones mapeadas (202,868 − 2,859 con concepto 0), en 5,706 personas. La ventana de 30 días fusionó 15,594 ocurrencias.

Condiciones con más eras (11.2):

| Condición | Eras | Personas | Eras por persona |
|---|---:|---:|---:|
| Medication review due | 29,807 | 5,706 | 5.22 |
| Gingivitis | 14,157 | 4,608 | 3.07 |
| Full-time employment | 12,720 | 4,470 | 2.85 |
| Stress | 13,734 | 4,468 | 3.07 |
| Part-time employment | 8,669 | 3,659 | 2.37 |
| Viral sinusitis | 5,832 | 3,615 | 1.61 |
| Limited social contact | 5,385 | 3,042 | 1.77 |
| Social isolation | 5,342 | 3,040 | 1.76 |
| Gingival disease | 4,412 | 2,706 | 1.63 |
| Body mass index 30+ - obesity | 2,687 | 2,687 | 1.00 |

La mayoría no son enfermedades sino situaciones administrativas o sociales (dominio Observation; ver §9). En una CONDITION_ERA hecha con un ETL correcto no estarían.

## 12. Posibles errores detectados y correcciones

1. **Consulta 2.3 (error del script, corregido).** Las duraciones negativas (end < start, 0.08 %, ≈ 217 filas) caían en el grupo "1–7 días". El fichero `farmacoepi.sql` ya tiene un grupo "0) NEGATIVA". Para eras y PDC no afecta: allí la duración mínima es de 1 día.
2. **Mapeo de unidades del ETL del Lab 12 (limitación real del `convertir.py`).** Compara la unidad de Synthea con `concept_code` de UCUM tal cual, pero ATHENA usa otra notación para varias unidades (`[U]/L`, `10*3.[U]/L`, `10*-3.[iU]/L`). Afecta a unas 96,528 mediciones (≈ 4.4 %) que se quedaron con `unit_concept_id = 0` aunque tienen concepto. Solución propuesta: una pequeña tabla de equivalencias Synthea → UCUM en el ETL. Se puede comprobar en DuckDB con:
   `SELECT concept_id, concept_code, concept_name, standard_concept, invalid_reason FROM concept WHERE vocabulary_id = 'UCUM' AND concept_id IN (8645, 8810, 9040, 9117);`
3. **Tabaquismo.** No se puede saber, con esta salida, adónde fue a parar 449868002 en condition_occurrence. La consulta 9.2 ya se amplió para buscarlo por código fuente.
4. **Unidades dudosas en los datos de Synthea (no son errores del ETL):** globulina "g/L" con valores en g/dL, RDW en % y en fL con el mismo código, filtrado glomerular en `mL/min`, densidad de orina siempre 1.0.
5. **Duplicados exactos de lisinopril:** 324 filas (24,334 → 24,010). Se eliminaron para el PDC y las eras. La salida no dice si vienen del origen o de combinaciones.

## 13. Limitación principal

**Los datos son sintéticos y son prescripciones.** Synthea renueva las recetas sin huecos, no genera valores erróneos ni centinelas y simula una adherencia casi perfecta. Por eso los resultados no dicen nada sobre pacientes reales: PDC ≥ 0.8 en el 90.2 %, gap_days = 0, 0 valores implausibles en adultos. Lo que sí demuestran es que el **método** funciona.

Otras limitaciones:
* Sin `days_supply`: la cobertura se deduce de fechas, con un supuesto (inicio + 29) que cambia el PDC.
* ETL del Lab 12:
  * tipo de registro genérico (EHR);
  * sin tabla OBSERVATION (51.6 % de condition_occurrence mal ubicado; tabaquismo perdido);
  * solo observaciones numéricas;
  * mapeo de unidades por texto exacto (≈ 4.4 % de unidades perdidas);
  * `observation_period` = del primer al último encuentro, sin los +60 días que sugiere THEMIS para EHR.
* Vocabulario sin RxNorm Extension (en Synthea no afecta: 0 % de fármacos sin mapear).
* Los rangos de DQD v1.4.1 son amplios, están orientados a adultos y fueron retirados en versiones posteriores de DQD.
* **Achilles** y **Data Quality Dashboard**, las herramientas OHDSI estándar, necesitan R; aquí solo se replicaron a mano algunas comprobaciones.

## Fuentes

* THEMIS — Rules for records with values (MEASUREMENT/OBSERVATION): https://ohdsi.github.io/Themis/records_with_values.html
* THEMIS — days_supply ausente: https://ohdsi.github.io/Themis/missing_days_supply.html
* THEMIS — drug_exposure_end_date no disponible (inicio + 29 en recetas escritas): https://ohdsi.github.io/Themis/drug_end_date_not_in_data.html
* THEMIS — verbatim_end_date: https://ohdsi.github.io/Themis/populate_verbatim_end_date.html
* THEMIS — eventos fuera del observation_period / fecha índice: https://ohdsi.github.io/Themis/events_outside_obs_period.html
* THEMIS — observation_period en EHR: https://ohdsi.github.io/Themis/obs_periods_for_ehr.html
* THEMIS — mapeos uno-a-muchos: https://ohdsi.github.io/Themis/one_to_many_mapping.html
* OMOP CDM v5.4 (DRUG_EXPOSURE, DRUG_ERA y CONDITION_ERA con ventana de 30 días, OBSERVATION vs MEASUREMENT): https://ohdsi.github.io/CommonDataModel/cdm54.html
* OHDSI Data Quality Dashboard v1.4.1, umbrales plausibleValueLow/High: https://github.com/OHDSI/DataQualityDashboard/blob/v1.4.1/inst/csv/OMOP_CDMv5.3.1_Concept_Level.csv (raw: https://raw.githubusercontent.com/OHDSI/DataQualityDashboard/v1.4.1/inst/csv/OMOP_CDMv5.3.1_Concept_Level.csv)
* MIMIC-IV, mimic-code `vitalsign.sql` (filtros de FC y PAS): https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts/measurement/vitalsign.sql
* PubChem, glucosa (CID 5793, masa molar 180.16 g/mol): https://pubchem.ncbi.nlm.nih.gov/compound/5793
* NIST SP 811, Apéndice B.9 (°C = (°F − 32)/1.8): https://www.nist.gov/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/nist-guide-si-appendix-b9
* Pharmacy Quality Alliance, medidas de adherencia PDC (umbral 80 %): https://www.pqa.org/measures/measures-resources/
* PDC: 3 Rates by Therapeutic Category (CBE 0541): https://www.p4qm.org/measures/0541
* Umbral de hipertensión estadio 2 (PAS ≥ 140 mm Hg, guía ACC/AHA 2017, J Am Coll Cardiol 2018;71(19):e127–e248), citado en la ficha PQA PDC-RASA: https://ww3.pharmacyquality.com/wp-content/uploads/2021/02/PDCRASAonepager.pdf
