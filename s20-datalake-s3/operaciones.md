# Operaciones del data lake (Lab 20)

## Preparación
    cd ~/s20-datalake-s3 && source venv/bin/activate
    export AWS_PROFILE=tesis   # credenciales en ~/.aws, nunca en el repo

## Scripts
| Script | Qué hace |
|---|---|
| crear_bucket.py | Crea el bucket privado, cifrado y versionado, con las zonas raw/staging/curated |
| s3util/ | Funciones subir, bajar, listar, existir y borrar (pruebas: `pytest tests/`, 5 aprobadas) |
| csv_a_parquet.py | Sube los CSV a raw/ y los Parquet particionados por año a staging/ |
| benchmark.ipynb | Compara la velocidad de consulta de CSV contra Parquet |
| lifecycle.py | Aplica las reglas de ciclo de vida |
| recuperar.py | Borra y recupera raw/prueba.txt quitando el marcador de borrado |

## Recuperar un archivo borrado
1. Listar versiones: `s3.list_object_versions(Bucket, Prefix)`.
2. Borrar el `DeleteMarker` con su VersionId.

## Seguridad
- Solo datos sintéticos.
- Sin credenciales en el repositorio; se revisa con `gitleaks detect` antes de los push.
