# Actividad 6. Agrupación de diagnósticos por jerarquía (CONCEPT_ANCESTOR)

**Diagnósticos:** CONDITION_OCCURRENCE en (-inf, -1], sin concept_id 0.
**Código:** `agrupar_dx.py`

| Paso | Resultado |
|---|---|
| Conceptos de diagnóstico distintos | **249** |
| Nivel 1 bajo "Disease" (4274025) | 46 categorías; cubren 179 conceptos (72%) |
| Nivel 2 bajo "Disease" | **163 categorías**; cubren 177 conceptos (71%) |
| Nivel 2 con prevalencia 5-95% | **93 categorías** (variables candidatas) |

## Criterio
1. Raíz: SNOMED "Disease" (concept_id 4274025). Cada diagnóstico se asigna a
   todos sus ancestros con `min_levels_of_separation = 2` desde la raíz.
2. Se elige el nivel 2 porque separa por sistema orgánico (cardiovascular,
   respiratorio, digestivo, renal), lo que clínicamente da más sentido.
3. Se conservan solo categorías con prevalencia entre 5% y 95%.

## Limitaciones
- El 28% de los conceptos (72 de 249) no cuelga de "Disease": son hallazgos
  aparentemente sociales y de situación sociodemográfica (p. ej. desempleo, escolaridad), que se tratan aparte.
- SNOMED es polijerárquico: un diagnóstico cae en varias categorías, lo que
  genera variables correlacionadas. 
