# Actividad 10

**Tipo:** variable medida después de la fecha índice.
**Variable:** `dias_seguimiento` = días desde el egreso hasta la muerte (o 90 si sobrevive).

| modelo | AUROC sin fuga | AUROC con fuga | AUPRC sin fuga | AUPRC con fuga |
|---|---|---|---|---|
| Logística | 0.733 | 0.995 | 0.159 | 0.994 |
| Bosque | 0.755 | 0.998 | 0.226 | 0.996 |

Validación: StratifiedGroupKFold (5 pliegues, por `person_id`), solo train,
mismos pliegues en ambas versiones.
## Mecanismo
La información salió de la tabla `death`: `dias_seguimiento` se calcula con
`death_date`, que ocurre en [1, 90] días DESPUÉS del egreso. Todo sobreviviente
tiene exactamente 90 y todo fallecido < 90, así que la variable es el desenlace
codificado. 

## Cómo se reconoce
AUROC ≈ 1 en un desenlace clínico difícil y poco plausible ; AUPRC ≈ 1 con prevalencia 6.7 %; una
sola variable domina. Pregunta de control: ¿podría calcular esta variable el
día índice? No.

## Corrección
Se elimina `dias_seguimiento` de los predictores (queda solo como tiempo para
Cox) y se agrega un `assert` que impide que vuelva a entrar. Las métricas vuelven
a 0.733/0.755 (AUROC) y 0.159/0.226 (AUPRC).
