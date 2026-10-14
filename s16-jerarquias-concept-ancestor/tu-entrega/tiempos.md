# Actividad 8 – Rendimiento (DuckDB, EXPLAIN ANALYZE)

**Motor:** DuckDB (EXPLAIN ANALYZE). Cada versión se corrió 3 veces y se reporta la mediana. Ambas devuelven 147 pacientes.

| Versión | Corrida 1 | Corrida 2 | Corrida 3 | Mediana |
|---|---|---|---|---|
| V1: `IN (subconsulta sobre CONCEPT_ANCESTOR)` | 6.1 ms | 4.5 ms | 4.3 ms | **4.5 ms** |
| V2: tabla temporal con índice + `JOIN` | 2.3 ms | 2.0 ms | 2.2 ms | **2.2 ms** |

La primera corrida de V1 fue la más lenta (6.1 ms) 

## Planes de ejecución

**V1** (Total Time 0.0053 s):
UNGROUPED_AGGREGATE → PROJECTION → HASH_JOIN (SEMI, condition_concept_id = #0)
  ├─ TABLE_SCAN condition_occurrence (Sequential Scan, 163 filas)
  └─ FILTER → TABLE_SCAN concept_ancestor (Sequential Scan, filtro ancestor_concept_id = 4182210, 216 filas, 0.03 s)

**V2** (Total Time 0.0030 s):
UNGROUPED_AGGREGATE → PROJECTION → HASH_JOIN (INNER, condition_concept_id = concept_id)
  ├─ TABLE_SCAN condition_occurrence (Sequential Scan, 163 filas)
  └─ TABLE_SCAN temp.cs_demencia (Index Scan, 215 filas)

Planes completos en `act8_salida.txt`.

## Qué cambió en el plan

En V1, cada vez que se corre la consulta, DuckDB recorre completa la tabla CONCEPT_ANCESTOR (Sequential Scan) para reconstruir el concept set y luego hace un SEMI JOIN. En V2 ese paso desaparece: el concept set ya está materializado y se lee con un Index Scan sobre una tabla de 216 filas, unida con un INNER JOIN.

**Conclusión honesta:** la mediana bajó de 4.5 a 2.2 ms, pero a esta escala la diferencia es despreciable en la práctica (milisegundos). La ventaja real de materializar aparece en bases grandes o cuando el mismo concept set se reutiliza en muchas consultas.
