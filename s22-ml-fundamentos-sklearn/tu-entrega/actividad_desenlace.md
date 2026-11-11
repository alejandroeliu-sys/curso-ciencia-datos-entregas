# Actividad 1 — Desenlace

**Definición:** muerte por cualquier causa (tabla `death` de OMOP) ocurrida
entre el día 1 y el día 90 después de la fecha índice (`cohort_start_date`,
 en la cohorte 1701).

**Ventana:** [1, 90] días. Se excluye el día 0 porque una muerte en la fecha
índice no es predecible al egreso y representa a una complicación adicional relacionada a la misma hospitalización y no a lo que se desea medir con respecto a la fragilidad. 90 días es el horizonte clínico estándar
post-egreso en personas mayores y coincide con mi proyecto final.

**Seguimiento:** fin de datos 2026-11-10. Se excluyen 71 personas sin 90 días
de seguimiento.

**Prevalencia:** 369 positivos de 5,814 personas (6.3 %). Supera los 50
eventos de factibilidad solicitados en el laboratorio.
