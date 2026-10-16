# Definición de cohorte – Laboratorio 17

**Alumno:** Alejandro Eliu Cedillo Rivero
**Base:** OMOP CDM v5.4 (Synthea) en DuckDB
**cohort_definition_id:** 1701
**Nombre:** Personas de 65 años o más en su primer egreso hospitalario elegible para calcular el HFRS

Esta cohorte es la base del proyecto final: predecir fragilidad y desenlaces adversos a 90 días después del egreso hospitalario, con variables clínicas, bioquímicas y el Hospital Frailty Risk Score (HFRS).

## Acrónimo PICOT

| | |
|---|---|
| **Población** | Personas de 65 años o más egresadas de una hospitalización. |
| **Exposición** | El egreso hospitalario índice: la primera visita de tipo hospitalización (visit_concept_id 9201) que termina a los 65 años o más. La fecha índice es la fecha de egreso (`visit_end_date`). |
| **Comparador** | No aplica: es una cohorte para un modelo predictivo, no una comparación entre dos tratamientos como un ensayo clínico. 
| **Desenlace** | Desenlace compuesto a 90 días: muerte, reingreso hospitalario (visita 9201) o visita a urgencias (visita 9203). |
| **Tiempo** | 730 días de observación previa (es decir dos años aproximadamente); lavado de 30 días; ventanas de criterios de 365 días hacia atrás; seguimiento de hasta 90 días después del egreso (la justificación esta abajo). |

## Los cuatro componentes

**1. Evento inicial.** La primera hospitalización por persona que termina cuando la persona ya tiene 65 años o más. Una fila por persona; la fecha índice es el día del egreso.

**2. Criterios de inclusión y exclusión** (todas las ventanas terminan en la fecha índice y quedan dentro de OBSERVATION_PERIOD):
- **Observación previa:** al menos 730 días continuos de OBSERVATION_PERIOD antes de la fecha índice.
- **Lavado:** ninguna otra hospitalización que termine en los 30 días previos al ingreso índice, para que el evento índice no sea en realidad un reingreso.
- **Inclusión 1:** al menos 2 visitas ambulatorias en los 365 días previos. 
- **Inclusión 2:** al menos una medición de creatinina (en sangre 3051825 o sérica 3016723) en los 365 días previos, porque es una variable predictora del proyecto (función renal).
- **Inclusión 3:** al menos una medición de albúmina sérica (3024561) en los 365 días previos, como marcador de estado nutricio e inflamación, muy ligado a la fragilidad.
- **Inclusión 4:** al menos una tasa de filtración glomerular estimada (46236952) en los 365 días previos, para estratificar la función renal.
- **Inclusión 5:** contar con el diagnóstico de multimorbilidad conocido como la presencia de por lo menos dos o más enfermedades crónicas distintas en los 730 días previos. 
- **Exclusión 1:** muerte el mismo día del egreso o antes. Quien muere en el hospital no tiene seguimiento después del egreso.
- **Exclusión 2:** diagnóstico de cáncer maligno en los 365 días previos. Su pronóstico a 90 días depende sobre todo del cáncer y no de la fragilidad.

**3. Estrategia de salida.** El seguimiento termina en lo que ocurra primero: 90 días después del egreso, la muerte o el fin de OBSERVATION_PERIOD. 
**4. Censura.** Se censura a quien llega al fin de OBSERVATION_PERIOD antes de los 90 días sin haber tenido el desenlace. Nunca se le sigue más allá de donde llegan los datos.

## Por qué estas ventanas (y qué pasaría con otras)

- **730 días de observación previa:** el HFRS original revisa 2 años de diagnósticos CIE-10. Con 365 días se perderían ítems y el puntaje de fragilidad quedaría subestimado.
- **30 días de lavado:** coincide con la definición clínica habitual de reingreso. Si fueran 365 días se excluiría justo a los pacientes con hospitalizaciones repetidas, que son los más frágiles y los que más interesan al proyecto.
- **365 días para los criterios de inclusión y exclusión:** reflejan el estado clínico reciente. Con 180 días quedarían fuera pacientes con seguimiento anual, como el control de creatinina; con 730 días contaría un cáncer ya resuelto.
- **90 días de seguimiento:** es la pregunta de la tesis. A 30 días (como en el estudio original del HFRS) habría menos eventos; más allá de 90 días el desenlace dependería menos de la hospitalización índice.
- **Gap de 30 días para unir hospitalizaciones:** el mismo valor que el lavado, para que las dos reglas sean consistentes.

## Limitación conocida de los datos

En esta base, cada persona tiene un único periodo de observación, con mediana de 10,477 días (28.7 años), y la base cubre de 1917 a 2026. Es un artefacto de Synthea. Por eso el filtro de observación previa casi no excluye a nadie.


## Decisión pendiente con el profesor: tamaño de muestra

Con todos los criterios de inclusión, la base actual (Synthea, 5,706 personas) deja solo a 224 pacientes con un primer egreso a los 65 años o más. Esto es antes de aplicar el lavado de 30 días y la exclusión por cáncer, así que la cohorte final será algo menor. El criterio más costoso es la albúmina sérica: quita 70 pacientes (de 294 a 224).Tras el lavado  y la exclusión por cáncer, la cohorte final es de 196 individuos Planteo ante ello dos caminos:

- **Camino 1. Mantener la base actual:** cohorte de un máximo de 196 pacientes, con todos los criterios. Probablemente insuficiente para entrenar con estabilidad un modelo de Cox o XGBoost si los desenlaces a 90 días son poco frecuentes. Si se quitara el criterio de albúmina, quedarían 294.
- **Camino 2. Generar una base Synthea nueva y más grande:** de 5,000 a 10,000 personas de 65 años o más, como se planteó en la propuesta, con los mismos criterios. Si se conserva la misma proporción observada (54.5 % de los egresos elegibles), se esperaría una muestra varias veces mayor. El número exacto solo se sabrá al generar la base. Este camino permite además incluir la tabla `death` (mortalidad) y el estado civil desde `patients.csv`.


## Revisión de immortal time bias

**Pregunta:** ¿algún criterio usa información posterior a la fecha índice para decidir si alguien entra, o para clasificar su exposición?

**Respuesta: no.** Todas las ventanas de inclusión y exclusión terminan en la fecha índice (`BETWEEN fecha_indice - INTERVAL N DAY AND fecha_indice`): la observación previa, el lavado, las visitas, la creatinina, la albúmina, la TFG, la multimorbilidad y el cáncer. 

**Riesgo que se evitó a propósito:** se pensó en exigir "al menos 90 días de seguimiento disponibles" para tener el desenlace completo. Eso habría sido immortal time: excluiría a quien muere o se censura pronto, usando información del futuro. En su lugar, esos pacientes se mantienen y se censuran.

**Corrección a la estrategia de salida:** la regla de unir hospitalizaciones separadas por 30 días o menos (patrón para fármacos) no se aplica, porque borraría los reingresos, que son el desenlace. La salida es el mínimo entre la fecha índice + 90 días y el fin de OBSERVATION_PERIOD.
