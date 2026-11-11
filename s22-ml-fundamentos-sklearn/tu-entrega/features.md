# Variables del modelo base (Lab 22)

Fecha índice = `cohort_start_date` (egreso, cohorte 1701).

| variable | definición | ventana | % faltante | por qué la incluyo |
|---|---|---|---|---|
| edad | año de la fecha índice − `year_of_birth` | día 0 | 0 % | principal predictor de mortalidad |
| sexo_masc | 1 si `gender_concept_id` = 8507 | fija | 0 % | valorar dimorfismo sexual |
| dm2_prev | ≥1 dx descendiente de 201826 (DM2) | (-∞, -1] | 0 % | comorbilidad crónica frecuente y asociada a mulmimortalidad importante |
| ic_prev | ≥1 dx descendiente de 316139 (insuf. cardiaca) | (-∞, -1] | 0 % | alta mortalidad post-egreso y complicación intrahospitalaria frecuente |
| erc_prev | ≥1 dx descendiente de 46271022 (ERC) | (-∞, -1] | 0 % | marcador de daño renal, su presencia se asocia a mayor mortalidad a corto y mediano plazo |
| demencia_prev | ≥1 dx descendiente de 4182210 (demencia) | (-∞, -1] | 0 % | ítem de más peso del HFRS (lab 14) |
| creatinina | último valor, LOINC 3016723 | [-365, 0] | 16.6 % | función renal |
| hemoglobina | último valor, LOINC 3000963 | [-365, 0] | 8.2 % | anemia, asociada a fragilidad en etapas avanzadas |
| muerte_90d | **desenlace**: muerte en [1, 90] | [1, 90] | 0 % | variable a predecir, no se incluye en el modelo ya que puede generar fugas |
| dias_seguimiento | días a muerte o 90 (censura) | [1, 90] | 0 % | solo para Cox, necesaria para mi proyecto final, no se incluye en el modelo porque puede generar fugas |

Nota: las comorbilidades usan todo el historial previo porque Synthea
registra las crónicas una sola vez, en su diagnóstico. Con [-365, -1]
la DM2 caía a 0.3 %. 
