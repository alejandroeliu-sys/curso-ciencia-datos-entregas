# Laboratorio 18: auditoría de la cohorte 1701

Autor: Alejandro Eliu Cedillo Rivero

Auditoría de la cohorte 1701 del Laboratorio 17 (primer egreso hospitalario a los 65 años
o más, base OMOP CDM v5.4 de Synthea en DuckDB): factibilidad, atrición, diagnóstico de
la definición y sensibilidad al lavado.

**Entregable principal:** `tu-entrega/diagnostico_cohorte.md`

## Archivos

| Archivo | Actividad |
|---|---|
| `factibilidad.sql` | 1. N, seguimiento y eventos |
| `orden_alternativo.sql` | 3. Cambio de orden de criterios |
| `incidencia.sql` | 5. Entradas por año y por edad |
| `codigos_entrada.sql` | 6. Diagnósticos de la hospitalización índice |
| `huerfanos.sql` | 7. Conceptos huérfanos (visitas 0) |
| `atlas_cohorte.sql` | 8. SQL exportado de ATLAS |
| `variantes_lavado.py` / `.csv` | 9. Lavados de 30, 180, 365 y 730 días |
| `traslape_variantes.py` / `.png` | 10. Traslape y anidamiento |

## Cómo reproducir

```bash
source ~/s10-sql-fundamentals/venv/bin/activate
python tu-entrega/variantes_lavado.py
python tu-entrega/traslape_variantes.py

Requiere ~/s12-omop-cdm-introduccion/omop.duckdb con la cohorte 1701 en results.cohort
y ~/s17-cohortes-omop-sql/tu-entrega/cohorte_definicion.sql.
