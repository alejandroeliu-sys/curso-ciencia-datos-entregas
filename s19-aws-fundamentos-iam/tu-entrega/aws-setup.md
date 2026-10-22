# Configuración segura de AWS (Laboratorio 19)

Autor: Alejandro Eliu Cedillo Rivero. Región: us-east-2 (Ohio).
Regla: Como lo ha comentado el profesor en la clase, nunca se pueden subir datos reales de pacientes ni credenciales al repositorio.

## 1. MFA en el usuario raíz
1. Inicia sesión como **usuario raíz** (Add session → "Sign in using root user email").
2. Ve a tu nombre (arriba a la derecha) → **Credenciales de seguridad** → **Asignar dispositivo MFA**.
3. Elige **Aplicación de autenticación**, escanea el QR y escribe dos códigos seguidos.
4. Nombre del dispositivo: `celular-raiz`.

Comprobante: `capturas/01_mfa_raiz.png`.
Nota: en el plan gratuito esta página no aparece. Hay que pasar al plan de pago (límite de 20 USD) de forma obligatoria y activar las funciones avanzadas. Los créditos se conservan.

## 2. Presupuesto con alertas
1. Busca **Administración de facturación y costos** → **Presupuestos** → **Crear presupuesto**.
2. Elige **Personalización (avanzado)** → **Presupuesto de costos**, mensual y fijo, de `05.0` USD.
3. Agrega cuatro alertas: 50 % y 80 % real, y 50 % y 80 % estimado (pista: lo que AWS estima).
4. Nombre: `lab19-5usd`.

Comprobantes: `capturas/02_presupuesto_config_1.png` y `capturas/02_presupuesto_lista.png`.
Nota: desde septiembre de 2026 AWS pide verificar el correo de las alertas. El correo de verificación no llegó, así que se entregó la captura de la lista en su lugar.

## 3. Usuario IAM para el trabajo diario
1. IAM → **Usuarios** → **Crear usuario** `alejandro`, con acceso a la consola y contraseña personalizada.
2. Permisos: política `AdministratorAccess`.
3. Asigna su propio MFA: `celular-raiz`.
4. Desde aquí se trabaja con este usuario, no con la raíz.

**Declaración de permisos:** `AdministratorAccess` es un permiso **amplio**, que se usó por practicidad en el laboratorio. Lo mínimo que realmente se necesitaba era S3 sobre el bucket del lab, IAM de lectura y el simulador, gestionar su propio MFA y crear sus claves de acceso. El privilegio mínimo se demuestra con la política de la sección 5.

Comprobantes: `capturas/03_usuario_iam.png`, `capturas/03_sesion_iam.png` y `capturas/03_mfa_usuario_iam.png`.

## 4. Bucket de S3
1. S3 → **Crear bucket** `alejandro-lab19-20261020`, en la región `us-east-2`.
2. Deja activado **Bloquear todo el acceso público**.
3. Crea las carpetas `publico/` y `privado/`, y sube `archivo.txt` (un texto inventado) a cada una.

Comprobante: `capturas/04_bucket.png`.

## 5. Política mínima
Archivo `politica_minima.json`. Solo permite `s3:GetObject` sobre `publico/*`.
- `Version`: la versión del lenguaje de políticas (siempre `2012-10-17`).
- `Effect`: `Allow`, es decir, permite.
- `Action`: `s3:GetObject`, que solo deja leer o descargar objetos.
- `Resource`: el ARN de los objetos dentro de `publico/`. El `/*` significa "todos los objetos de esa carpeta".
- No incluye `s3:ListBucket` porque el notebook descarga el archivo por su nombre exacto y no necesita listar.

(JSON no admite comentarios, por eso la explicación va aquí.)

## 6. Simulador de políticas
Ver `simulador.md`: 4 casos, 1 permitido y 3 denegados por denegación implícita.

## 7. AWS CLI y perfil
1. Instala la AWS CLI v2 (instalador oficial `.zip`) y comprueba con `aws --version`.
2. IAM → `alejandro` → **Credenciales de seguridad** → **Crear clave de acceso** (caso de uso: CLI).
3. `aws configure --profile tesis`, con región `us-east-2` y salida `json`.
4. Comprueba con `aws sts get-caller-identity --profile tesis`. El ARN debe terminar en `user/alejandro`.
5. Las claves quedan en `~/.aws/`, **fuera** del repositorio.

Comprobantes: `capturas/07_sts.png` y `capturas/07_aws_fuera_repo.png`.

## 8. Notebook de verificación
`verificacion.ipynb` usa `boto3.Session(profile_name="tesis")`, lista los buckets y descarga `publico/archivo.txt`. No contiene ninguna clave.
Nota: listar buckets funciona por el `AdministratorAccess`. Con la política mínima sola, solo funcionaría la descarga.

Comprobante: `capturas/08_notebook.png`.

## 9. Revisión de secretos
`gitleaks git . -v` sobre todo el historial: 9 commits revisados, sin fugas. Salida en `gitleaks_salida.txt`.

## 10. Limpieza
- Borrar el bucket al terminar (primero vaciarlo).
- Revisar Cost Explorer.
- Dejar el presupuesto activo.
