# Laboratorio 17 – Cohorte de nuevo egreso hospitalario (65+)

**Alumno:** Alejandro Eliu Cedillo Rivero
**Base:** OMOP CDM v5.4 (Synthea) en DuckDB · **cohort_definition_id:** 1701
**Conexión con la proyecto final:** es la cohorte del proyecto final (desenlaces a 90 días con HFRS).

## Entregables (`tu-entrega/`)
| Archivo | Contenido |
|---|---|
| `cohorte_definicion.md` | PICOT, los cuatro componentes, la justificación de cada ventana y el immortal time |
| `cohorte_definicion.sql` | Un CTE por componente, comentado |
| `atricion.md` | Tabla paso a paso (411 → 196) |
| `caracterizacion.md`, `histograma_seguimiento.png` | Tabla 1 e histograma del seguimiento |
| `primeros_egresos_por_anio.png` | Trampa 2: primeros egresos por año, antes y después |
| `revision_op.sql`, `disponibilidad_variables.sql`, `tamano_muestra.sql` | Revisiones previas |
| `insertar_cohorte.py`, `caracterizacion.py`, `grafica_primeros_egresos.py` | Scripts |

## Limitaciones
- La base no tiene las tablas `death` ni `observation`: falta la mortalidad y el estado civil (se cargarán desde `patients.csv`).
- Un único periodo de observación de unos 28.7 años por persona: la observación previa no excluye a nadie.
- No hay cistatina C, IL-1 ni MET en Synthea.
- La salida no usa el patrón de "gaps and islands" de 30 días porque borraría los reingresos (justificado en la definición).
