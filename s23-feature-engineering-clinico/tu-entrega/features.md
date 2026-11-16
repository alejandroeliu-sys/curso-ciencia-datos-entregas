# Diccionario de features (Lab 23)

Matriz: `build_features.sql` → `features.csv` . N = 5,372
personas (primer egreso hospitalario a los 65+ años, cohorte 1701; 369 muertes
a 90 días, 6.9%). Fuente: base sintética Synthea en OMOP CDM v5.4
(`omop_20k.duckdb`). Día 0 = fecha de egreso de la hospitalización índice.
Ninguna variable usa información posterior al día 0, salvo el desenlace.

| variable | definición | ventana | unidades | % faltante | fuente | por qué |
|---|---|---|---|---|---|---|
| person_id | Identificador sintético de la persona | — | id | 0 | person | Llave; no se usa como predictor |
| fecha_indice | Fecha de egreso de la hospitalización índice (día 0) | día 0 | fecha | 0 | visit_occurrence | Ancla temporal; no se usa como predictor |
| edad | Edad al día 0 (años cumplidos) | día 0 | años | 0 | person | Principal determinante de mortalidad |
| sexo_masc | Sexo masculino (1) vs femenino (0) | — | 0/1 | 0 | person | Confusor clásico; entra en CKD-EPI |
| obs_previa_dias | Días de observación antes del día 0 | (−∞, 0] | días | 0 | observation_period | Controla la cantidad de historia disponible |
| dm2_dx | Diagnóstico previo de diabetes tipo 2 (descendientes de 201826) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Comorbilidad de riesgo |
| ic_dx | Insuficiencia cardiaca (316139 y descendientes) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Fuerte predictor de muerte a corto plazo |
| erc_dx | Enfermedad renal crónica (46271022 y descendientes) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Comorbilidad de riesgo |
| demencia_dx | Demencia (4182210 y descendientes) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Ítem de mayor peso del HFRS; fragilidad |
| cardiop_isq_dx | Cardiopatía isquémica (4185932 y descendientes) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Comorbilidad cardiovascular |
| hta_dx | Hipertensión (320128 y descendientes) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Comorbilidad muy prevalente |
| anemia_dx | Anemia (439777 y descendientes) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Marcador de fragilidad |
| dislipidemia_dx | Dislipidemia (432867 y descendientes) | (−∞, −1] | 0/1 | 0 | condition_occurrence + concept_ancestor | Riesgo cardiovascular |
| n_ingredientes_365 | Ingredientes activos distintos (roll-up a Ingredient) | [−365, −1] | conteo | 0 | drug_exposure + concept_ancestor | Polifarmacia |
| n_ingredientes_30 | Ingredientes activos distintos | [−30, −1] | conteo | 0 | drug_exposure + concept_ancestor | Polifarmacia reciente |
| dm_inferida | Antidiabético (1503297, 1596977 o 46221581) en ≥2 fechas | (−∞, −1] | 0/1 | 0 | drug_exposure | Captura diabetes no codificada |
| hta_inferida | Antihipertensivo (1308216, 974166, 1332418 o 1367500) en ≥2 fechas | (−∞, −1] | 0/1 | 0 | drug_exposure | Captura hipertensión no codificada |
| ic_inferida | Furosemida en ≥2 fechas + carvedilol o metoprolol | (−∞, −1] | 0/1 | 0 | drug_exposure | Captura IC no codificada |
| dislipidemia_inferida | Simvastatina en ≥2 fechas | (−∞, −1] | 0/1 | 0 | drug_exposure | Captura dislipidemia no codificada |
| albumina_ultima | Último valor de albúmina sérica | (−∞, 0] | g/dL | 0.4 | measurement | Estado nutricional; fragilidad |
| albumina_n | Número de mediciones de albúmina | (−∞, 0] | conteo | 0 | measurement | Intensidad de seguimiento |
| albumina_pendiente | Pendiente de albúmina en el tiempo (≥3 fechas) | (−∞, 0] | g/dL por día | 43.2 | measurement | Deterioro nutricional |
| albumina_de | Desviación estándar de albúmina (≥3 fechas) | (−∞, 0] | g/dL | 43.2 | measurement | Inestabilidad |
| creatinina_ultima | Último valor de creatinina sérica | (−∞, 0] | mg/dL | 10.5 | measurement | Función renal |
| creatinina_n | Número de mediciones de creatinina | (−∞, 0] | conteo | 0 | measurement | Intensidad de seguimiento |
| creatinina_pendiente | Pendiente de creatinina (≥3 fechas) | (−∞, 0] | mg/dL por día | 56.4 | measurement | Deterioro renal |
| egfr_ckdepi2021 | eGFR CKD-EPI 2021 sin raza; NULL si creatinina fuera de 0.2–20 | (−∞, 0] | mL/min/1.73 m² | 11.5 | derivada (creatinina, edad, sexo) | Índice validado de función renal |
| urea_ultima | Último valor de urea/BUN | (−∞, 0] | mg/dL | 10.5 | measurement | Función renal e hidratación |
| urea_n | Número de mediciones de urea | (−∞, 0] | conteo | 0 | measurement | Intensidad de seguimiento |
| urea_pendiente | Pendiente de urea (≥3 fechas) | (−∞, 0] | mg/dL por día | 56.4 | measurement | Deterioro renal |
| pas_ultima | Última presión arterial sistólica | (−∞, 0] | mmHg | 1.3 | measurement | Estado hemodinámico |
| imc_ultimo | Último índice de masa corporal | (−∞, 0] | kg/m² | 1.5 | measurement | Estado nutricional |
| n_ambulatorias_365 | Visitas ambulatorias | [−365, −1] | conteo | 0 | visit_occurrence | Utilización; explica faltantes (MAR) |
| n_hosp_365 | Hospitalizaciones previas (excluye la índice) | [−365, −1] | conteo | 0 | visit_occurrence | Gravedad y reingreso |
| n_urgencias_365 | Visitas a urgencias | [−365, −1] | conteo | 0 | visit_occurrence | Inestabilidad clínica |
| estancia_indice_dias | Duración de la hospitalización índice | estancia índice | días | 0 | visit_occurrence | Gravedad del evento índice |
| muerte_90d | Desenlace: muerte en días [1, 90] tras el egreso | [1, 90] | 0/1 | 0 | death | Variable objetivo; no es predictor |


