# Laboratorio 21 — Análisis en EC2

## 1. Justificación de la instancia

**Memoria.** El pipeline (DuckDB leyendo Parquet de S3) tuvo un pico de 321,668 KB (unos 314 MB), medido con `/usr/bin/time -v` en mi laptop. Sumando el sistema operativo y Docker (unos 500 MB), 2 GB dejan un margen bastante aceptable.

**Tiempo.** En mi laptop tarda 4.7 s (wall clock 0:04.90) para procesar los encounters de 20 mil pacientes sintéticos (155 MB en Parquet).

**¿Por qué EC2?** Para este volumen, mi laptop alcanza. Uso EC2 para aprender a tener una máquina completa (SSH, Jupyter, tmux, rol IAM) cerca de los datos, en la misma región que el bucket (us-east-2), sin pagar transferencia entre regiones.

**Instancia elegida: t3.small** (2 vCPU, 2 GB, unos USD 0.02 por hora on-demand). Es burstable, en un trabajo de segundos no agota los créditos de CPU. Para un trabajo largo parecen mejores opciones m7i o c7i.

## 2. Rol IAM de privilegio mínimo

Rol `ec2-pipeline-fragilidad`, que solo puede asumir EC2. Política en línea `minimo-s3-ecr` (ver `politica_rol.json`): leer `staging/*`, leer y escribir `results/*` y descargar la imagen de ECR. No usa AmazonS3FullAccess.

Simulador (`aws iam simulate-custom-policy`):
| Acción | Recurso | Resultado |
|---|---|---|
| s3:GetObject | staging/synthea/x.parquet | allowed |
| s3:PutObject | results/x.csv | allowed |
| s3:PutObject | staging/x.parquet | implicitDeny |
| s3:GetObject | raw/prueba.txt | implicitDeny |

Nota: `simulate-principal-policy` sobre el rol devolvió `explicitDeny` sin ninguna declaración que coincida, así que validé la política con `simulate-custom-policy`, posteriormente la comprobaré en la instancia.

## 3. Lanzamiento de la instancia

- AMI: Amazon Linux 2023 (`ami-02dae70ab25064279`), tipo `t3.small`, región `us-east-2`.
- Perfil de instancia: `ec2-pipeline-fragilidad` (rol, sin llaves en la máquina).
- Grupo de seguridad `sg-0b237bb4e7a99f429`: solo puerto 22 desde mi IP `/32`. Nunca `0.0.0.0/0`. El puerto 8888 no está abierto.
- Key pair `lab21-fragilidad`. El PEM vive fuera del repo con `chmod 400`.

## 4. User data

El script `user-data.sh` (en esta carpeta) instala y arranca Docker en el primer arranque, sin intervención manual.
```bash
#!/bin/bash
set -euxo pipefail
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
```
Verificación: `sudo systemctl is-active docker` → `active`; `docker --version` → `Docker version 25.0.14`.

## 5. Ejecución del pipeline

```bash
aws ecr get-login-password --region us-east-2 | sudo docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-2.amazonaws.com
sudo docker pull <ACCOUNT_ID>.dkr.ecr.us-east-2.amazonaws.com/pipeline-fragilidad:1.0
sudo docker run --rm <ACCOUNT_ID>.dkr.ecr.us-east-2.amazonaws.com/pipeline-fragilidad:1.0
```

Salida: `Listo en 12.2 s -> s3://fragilidad-datalake-ace-2026/results/encuentros_por_anio.csv`.
Lee `staging/` y escribe `results/` directamente en S3, no en el disco de la instancia.

## 6. Sin credenciales en la máquina

- `env | grep -i AWS` → vacío.
- `ls -la ~/.aws` → solo `cli/` (caché), sin `credentials` ni `config`.
- Metadata IMDSv2 `iam/security-credentials/` → `ec2-pipeline-fragilidad`.

Las credenciales son temporales y las entrega el rol de la instancia.

## 7. Jupyter por túnel SSH

```bash
ssh -i ~/lab21-fragilidad.pem -L 8888:localhost:8888 ec2-user@<IP>
~/.local/bin/jupyter notebook --no-browser --port=8888 --ip=127.0.0.1
```

Jupyter escucha solo en `127.0.0.1` de la instancia y lo abrí en `http://127.0.0.1:8888` de mi laptop.

## 8. tmux

`tmux new -s pipeline`, corrí el pipeline (11.5 s), salí con `Ctrl+B d`, `tmux ls` mostró la sesión viva sin `attached`, y volví a entrar con `tmux attach -t pipeline`.

## 9. Spot vs on-demand (t3.small, us-east-2)

| Modalidad | USD/hora |
|---|---|
| On-demand | 0.0208 |
| Spot us-east-2c | 0.0033 |
| Spot us-east-2b | 0.0042 |
| Spot us-east-2a | 0.0040 |



## 10. Apagado y costo

- Alarma CloudWatch `lab21-apagado-inactiva`: CPU promedio < 5 % durante 6 periodos de 5 min (30 min),  con acción `arn:aws:automate:us-east-2:ec2:stop`.
- Instancia `i-0c53c2659f01249fb` terminada (`terminate-instances`); `describe-instances` con estados pending/running/stopping/stopped devuelve tabla vacía: no queda nada encendido ni disco EBS cobrando.
- Costo medido con Cost Explorer (`aws ce get-cost-and-usage`, 2026-11-04 a 2026-11-07, UnblendedCost por servicio): EC2 Compute 0 USD, ECR 0, S3 ~0, VPC 0, Data Transfer y EC2-Other ±0.0000001 USD. Total ≈ 0 USD. Cost Explorer tiene hasta 24 h de retraso, así que el uso del 6 y 7 de noviembre puede actualizarse después; el máximo esperado es ~0.02 USD/h × horas encendida.
