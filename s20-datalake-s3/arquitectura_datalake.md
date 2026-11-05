# Arquitectura del data lake clínico (Lab 20)

**Bucket:** fragilidad-datalake-ace-2026 (us-east-2), privado, cifrado AES256, versionado activo,con  bloqueo de acceso público.
**Datos:** solo sintéticos (Synthea).

## Zonas
| Zona | Contenido | Formato |
|---|---|---|
| raw/ | CSV originales de Synthea, sin modificar | CSV |
| staging/ | Tablas limpias particionadas por año (`anio=`) | Parquet zstd |
| curated/ | Tablas analíticas para el modelo (cohorte, features) | Parquet |

## Resultados
| Tabla | CSV | Parquet |
|---|---|---|
| patients | 11 MB | 4 MB |
| encounters | 1,309 MB | 155 MB |
| conditions | 325 MB | 49 MB |

Benchmark (conteo por año de encounters): CSV 0.39 s y Parquet 0.037 s, con lo que Parquet es 10.4 veces más rápido.
Costo estimado: unos USD 0.04 al mes por cerca de 1.85 GB.

## Ciclo de vida
- raw/ pasa a STANDARD_IA a los 30 días y a GLACIER_IR a los 90.
- Las versiones no actuales se borran a los 30 días; las subidas multiparte incompletas, a los 7.
