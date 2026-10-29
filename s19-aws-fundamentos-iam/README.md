# Laboratorio 19: Configurar una cuenta AWS de forma segura

Autor: Alejandro Eliu Cedillo Rivero

Todos los archivos están en `tu-entrega/`:
- `aws-setup.md`: el procedimiento completo, con capturas censuradas.
- `politica_minima.json`: la política de privilegio mínimo (se explica abajo).
- `simulador.md`: los 4 casos del simulador de políticas.
- `verificacion.ipynb`: boto3 con el perfil `tesis`, sin claves.
- `gitleaks_salida.txt`: el escaneo de todo el historial, sin fugas.

## Política mínima, renglón por renglón

    {
      "Version": "2012-10-17",                  
      "Statement": [                            
        {
          "Effect": "Allow",                    
          "Action": "s3:GetObject",             
          "Resource": "arn:aws:s3:::alejandro-lab19-20261020/publico/*"
                                       
        }
      ]
    }

- Todo lo demás (privado/, escribir, borrar) queda en **denegación implícita**.
- No se incluye `s3:ListBucket` porque el notebook descarga el archivo por su nombre exacto.
- JSON no admite comentarios, por eso la explicación va aquí.

## Limitaciones
- El usuario IAM `alejandro` tiene `AdministratorAccess`, que es un permiso amplio. El privilegio mínimo se demuestra con la política y el simulador.
- El correo de verificación de AWS Budgets no llegó, así que se entregó una captura en su lugar.
