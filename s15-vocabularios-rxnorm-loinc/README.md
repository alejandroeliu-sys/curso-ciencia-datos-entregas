# Laboratorio 15 – Vocabularios RxNorm y LOINC

**Alumno:** Alejandro Eliu Cedillo Rivero
**Base:** OMOP CDM v5.4, datos Synthea (DuckDB)
**Vocabularios:** RxNorm 20260601, LOINC 2.82, ATC 2026-02-01, UCUM

## Resultados principales

| Actividad | Resultado |
|---|---|
| 1. RxNav | Metformina (RxCUI 6809), colecalciferol (2418), dexametasona (3264) |
| 2. Top 20 | 20 productos → 23 ingredientes (3 combinaciones) |
| 3. ATC | A10B: 42 ingredientes; 0.07 % de registros sin ATC |
| 4. Metformina | Versiones A, B y C coinciden: 228 pacientes |
| 5. LOINC | Seis ejes de HbA1c, creatinina y glucosa |
| 6. HbA1c | 42,422 mediciones, solo con 4548-4 |
| 7. Unidades | 100 % en %, rango 2.3–9.6 |
| 8. Catálogo local | 15 términos mapeados (9 LOINC, 6 RxNorm) |
| 9. Concept sets | metformina, hba1c, funcion_renal |

## Limitaciones

- RxNorm Extension no está cargado; Synthea solo usa RxNorm, aunque no descargar la extensión se solicito en un laboratorio previom, ya que solo se indicó descargar RxNorm. 
- Synthea tiene un solo producto de metformina, por eso las versiones A, B y C coinciden.
- La cistatina C no tiene mediciones en Synthea (0); la creatinina sí (29,684 mediciones, 987 pacientes).
- La distribución de HbA1c muestra picos artificiales propios de datos sintéticos.

## Archivos

Todos los entregables están en `tu-entrega/`, y los concept sets en `tu-entrega/concept_sets/`.
