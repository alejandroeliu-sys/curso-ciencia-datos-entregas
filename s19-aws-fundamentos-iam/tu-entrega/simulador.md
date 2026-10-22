# Actividad 6: Simulador de políticas de IAM

## Qué se probó
Se evaluó solo la política `politica_minima.json` en el modo **Personalizado** del IAM Policy Simulator, sin incluir el AdministratorAccess del usuario `alejandro`. Si se hubiera incluido, ese permiso habría permitido todo.

Bucket: `alejandro-lab19-20261020` (región us-east-2).

## Resultados

| Caso | Acción | Recurso | Esperado | Resultado real |
|---|---|---|---|---|
| 1 | s3:GetObject | publico/archivo.txt | Permitido | Permitido |
| 2 | s3:GetObject | privado/archivo.txt | Denegado | Denegado |
| 3 | s3:PutObject | publico/archivo.txt | Denegado | Denegado |
| 4 | s3:DeleteObject | privado/archivo.txt | Denegado | Denegado |

## Interpretación
El caso 1 se permite porque coinciden la acción y el recurso (`publico/*`) de la instrucción Allow. Los casos 2, 3 y 4 se deniegan por **denegación implícita** (pista: dos palabras, lo que AWS muestra cuando ninguna instrucción coincide). Esto demuestra el principio de privilegio mínimo.

## Nota
El simulador nuevo admite un solo ARN de tipo `object` por acción, así que los casos se corrieron en dos simulaciones.

## Capturas (ID de cuenta tachado)
- `capturas/06_simulador_1.png`: casos 1, 3 y 4
- `capturas/06_simulador_2.png`: caso 2
