# Laboratorio 16 – Jerarquías y CONCEPT_ANCESTOR

**Alumno:** Alejandro Eliu Cedillo Rivero
**Datos:** OMOP CDM v5.4 con datos sintéticos de Synthea, en DuckDB
**Concepto semilla:** demencia, SNOMED 52448006 (concept_id 4182210)

## Archivos entregados (`tu-entrega/`)

| Archivo | Contenido |
|---|---|
| `jerarquias.sql` | Las consultas de las actividades 1 a 7, cada una con un comentario que dice qué responde y qué se encontró |
| `act2_*.sql` a `act7_*.sql` | Las mismas consultas, cada actividad en su propio archivo |
| `act8_tiempos.py`, `act8_salida.txt` | Comparación de rendimiento entre las versiones V1 y V2 |
| `tiempos.md` | Tiempos y planes de ejecución (actividad 8) |
| `act6_salidas.txt` | Salida de "¿por qué entró este paciente?" para 3 pacientes |
| `notas_act1_2.md`, `notas_act3.md` | Notas de las actividades 1 a 3 |
| `hallazgos.md` | Polijerarquía y hallazgos de las actividades 5, 6 y 7 |

## Resultados principales

- **Actividad 1:** la consulta recursiva hacia arriba encuentra 22 ancestros, con raíz SNOMED CT Concept (4008453) y profundidad de 5 a 9 niveles.
- **Actividad 2:** CONCEPT_ANCESTOR devuelve 16. Los 6 que faltan son conceptos no estándar, que CONCEPT_ANCESTOR no guarda.
- **Actividad 3:** hay 724 tipos de relación; 124 son jerárquicos, 63 definen ancestría y 55 cumplen ambas cosas. De metformina salen 9 tipos de relación.
- **Actividad 4:** hay 15 casos de polijerarquía. Por ejemplo, 4046090 se alcanza por un camino de 3 niveles y por otro de 4.
- **Actividad 5:** A da 294 (inflado por filas duplicadas del JOIN), B da 2 y C da 147 (el valor correcto).
- **Actividad 6:** los pacientes 51, 117 y 371 entraron por SNOMED 26929004, que se mapea a Alzheimer (378419), aqui en lugar de solicitar apoyo de un compañero, se opto por elegir un número al azar.
- **Actividad 7:** los 216 conceptos son válidos, así que no se gana ni se pierde ningún paciente.
- **Actividad 8:** V1 tarda 4.5 ms y V2 2.2 ms (medianas). Hay mejoria en el tiempo, pero pequeña a esta escala.

## Notas y limitaciones

- **Synthea:** en los datos solo hay Alzheimer (378419) y Alzheimer familiar de inicio temprano (4043241). No hay demencia vascular ni subcortical, así que algunas ramas dan 0 pacientes.
- **Escala:** la base es pequeña, así que las diferencias de rendimiento son de milisegundos.
