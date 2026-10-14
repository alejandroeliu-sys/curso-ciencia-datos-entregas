# Hallazgos – Laboratorio 16

## Poli-jerarquía (actividad 4)

**Par:** Dementia (4182210) → Mixed cortical and subcortical vascular dementia (4046090). En CONCEPT_ANCESTOR: min_levels = 3, max_levels = 4.
#Los caminos son los siguientes: 
**Camino 1 (3 niveles):**
Dementia (4182210) → Subcortical dementia (42538857) → Subcortical vascular dementia (4047747) → Mixed cortical and subcortical vascular dementia (4046090)

**Camino 2 (4 niveles):**
Dementia (4182210) → Dementia associated with another disease (374888) → Vascular dementia (443605) → Subcortical vascular dementia (4047747) → Mixed cortical and subcortical vascular dementia (4046090)

**Interpretación clínica:** tiene sentido que pertenezca a las dos ramas porque SNOMED clasifica la demencia por dos ejes a la vez: la localización del daño (subcortical) y su causa (enfermedad vascular). Se puede considerar como un camino con un enfoque más anatómico y al segundo más funcional. Un mismo diagnóstico responde a ambas preguntas.

## Medir el daño del traslape (actividad 5)

Concept set con dos ramas traslapadas: Dementia (4182210) y Alzheimer's disease (378419).

| Conteo | Resultado | Qué significa |
|---|---|---|
| A: COUNT(*) del JOIN | 294 | Filas duplicadas: cada registro se une una vez por cada rama. No tiene significado clínico. |
| B: COUNT(DISTINCT concept_id) | 2 | Diagnósticos distintos usados (Alzheimer y Alzheimer familiar de inicio temprano). |
| C: COUNT(DISTINCT person_id) | 147 | Pacientes con la condición. Es el único que responde «¿cuántos pacientes tienen demencia?». |

Nota: el primer intento con Vascular dementia y Subcortical dementia dio 0 en los tres conteos porque Synthea no genera esos diagnósticos.

## ¿Por qué entró este paciente? (actividad 6)

Consulta parametrizable. Salidas completas en `act6_salidas.txt`.

| Paciente | Evento | Fecha | Código fuente | Concepto estándar | Ramas por las que entra |
|---|---|---|---|---|---|
| 51 | 2448 | 2017-09-20 | SNOMED 26929004 | Alzheimer's disease (378419) | Dementia (1 nivel) y Alzheimer's disease (0 niveles) |
| 117 | 4847 | 1988-12-08 | SNOMED 26929004 | Alzheimer's disease (378419) | Dementia (1 nivel) y Alzheimer's disease (0 niveles) |
| 371 | 14883 | 2023-05-01 | SNOMED 26929004 | Alzheimer's disease (378419) | Dementia (1 nivel) y Alzheimer's disease (0 niveles) |

**Camino:** person_id → evento en condition_occurrence → código fuente SNOMED 26929004 → concepto estándar Alzheimer's disease (378419) → ancestro del concept set (Dementia 4182210 o Alzheimer's disease 378419).

**Elección de pacientes:** trabajé sin grupo, así que en lugar de que un compañero me  eligiera el tercer paciente, lo seleccioné al azar usando `ORDER BY random() LIMIT 1` sobre la cohorte de demencia (salió el 371). 

**Observación:** cada paciente aparece en dos filas porque entra por las dos ramas del concept set.





## Conceptos retirados (actividad 7)

| invalid_reason | Conceptos |
|---|---|
| NULL (vigente) | 216 |
| D (eliminado) | 0 |
| U (reemplazado) | 0 |

**Efecto de la corrección:** 0 pacientes ganados o perdidos.

**Interpretación:** CONCEPT_ANCESTOR solo contiene conceptos estándar vigentes, así que un concept set construido con él no incluye conceptos muertos. 
