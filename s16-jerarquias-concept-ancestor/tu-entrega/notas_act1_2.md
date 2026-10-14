# Actividades 1 y 2

**Actividad 1 (WITH RECURSIVE): 22 conceptos (demencia + 21 ancestros). Raíz: SNOMED CT Concept (4008453). Profundidad: 5 a 9 niveles según el camino.

**Actividad 2 (CONCEPT_ANCESTOR): 16 conceptos.Por lo cual, no son idénticos: faltan 6, los que no son estándar son= (standard_concept = NULL): Disorder by body site, SNOMED CT Concept, Clinical history and observation findings, Finding of head and neck region, Finding of body region, Finding by site.

**Explicación:  CONCEPT_ANCESTOR solo incluye conceptos estándar, mientras que la recursiva sigue cualquier relación 'Is a'. Por eso también cambian los niveles máximos (por ejemplo, Clinical finding: 8 en la recursiva, 7 en CONCEPT_ANCESTOR).
