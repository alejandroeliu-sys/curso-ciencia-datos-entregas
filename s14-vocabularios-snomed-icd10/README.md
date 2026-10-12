# Laboratorio 14: Construir y defender un concept set

**Alumno:** Alejandro Eliu Cedillo Rivero
**Base:** OMOP CDM v5.4 en DuckDB (datos Synthea), vocabularios ATHENA

## Objetivo
Definir demencia con vocabularios estándar, medir cómo cambia el tamaño de la cohorte según la definición y justificación de la versión elegida. Demencia se eligió porque es el ítem con más peso del Hospital Frailty Risk Score (HFRS), que uso en mi proyecto final con adultos de 65 años o más.

## Concepto semilla
4182210 Dementia (SNOMED 52448006), estándar y vigente.

## Resultados
| Versión | Conceptos | Pacientes |
|---|---:|---:|
| A estricta (solo la semilla) | 1 | 0 |
| B amplia (semilla y descendientes) | 216 | 147 |
| C razonada (B menos exclusiones) | 190 | 116 |

La versión C tiene 21.1 % menos pacientes que la B. En la revisión manual de 20 descendientes al azar, 10 (50 %) no correspondían a demencia degenerativa o vascular de inicio tardío.

Los 13 códigos CIE-10-CM de demencia se mapean con "Maps to" a 17 conceptos estándar: 4 códigos tienen más de un destino y ninguno quedó sin mapeo.

## Archivos
- `tu-entrega/concept_set.sql`: todas las consultas, con su título
- `tu-entrega/justificacion_concept_set.md`: tabla de decisiones y discusión de sensibilidad y valor predictivo positivo
- `tu-entrega/impacto_pacientes.png`: gráfica de pacientes por versión
- `tu-entrega/grafica_impacto.py`: script que genera la gráfica
- `tu-entrega/version_*.sql`, `pacientes_*.sql`, `icd10_maps_to.sql`, `muestra_20.sql`: consultas por separado


