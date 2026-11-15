# Parte C. Datos faltantes

## Actividad 7. Faltante vs desenlace 

| Variable | % faltante | Muerte % con dato | Muerte % sin dato | p (χ²) | Mecanismo |
|---|---|---|---|---|---|
| albumina_ultima | 0.4 | 6.9 | 0.0 | 0.439 | MCAR posible |
| albumina_pendiente / albumina_de | 43.2 | 10.0 | 2.7 | <0.001 | MAR |
| creatinina_ultima / urea_ultima | 10.5 | 7.2 | 3.7 | 0.003 | MAR  |
| egfr_ckdepi2021 | 11.5 | 7.3 | 3.6 | 0.001 | MAR |
| creatinina_pendiente / urea_pendiente | 56.4 | 6.7 | 7.0 | 0.714 | Sin asociación con variable desenlace |
| pas_ultima | 1.3 | 6.9 | 4.2 | 0.498 | MCAR posible |
| imc_ultimo | 1.5 | 6.9 | 6.4 | 1.000 | MCAR posible |

**Dependencia de variables observadas** (con dato vs sin dato)

| Variable | Edad | Visitas ambulatorias | Hosp. previas | Ingredientes | IC (%) |
|---|---|---|---|---|---|
| creatinina_ultima | 74.3 vs 72.4 | 29.3 vs 5.3 | 0.05 vs 0.01 | 8.9 vs 11.2 | 21 vs 0 |
| albumina_pendiente | 74.6 vs 73.3 | 42.7 vs 5.9 | 0.07 vs 0.01 | 8.9 vs 9.5 | 28 vs 7 |


## Actividad 8. Indicadores `<var>_ausente`

Se creó un indicador 0/1 por cada variable con faltantes (script `ausentes.py`).

| Indicador | n ausente | % ausente | Muerte % si ausente |
|---|---|---|---|
| creatinina_pendiente_ausente / urea_pendiente_ausente | 3,030 | 56.4 | 7.0 |
| albumina_pendiente_ausente / albumina_de_ausente | 2,319 | 43.2 | 2.7 |
| egfr_ckdepi2021_ausente | 619 | 11.5 | 3.6 |
| creatinina_ultima_ausente / urea_ultima_ausente | 562 | 10.5 | 3.7 |
| imc_ultimo_ausente | 78 | 1.5 | 6.4 |
| pas_ultima_ausente | 72 | 1.3 | 4.2 |
| albumina_ultima_ausente | 20 | 0.4 | 0.0 |

Mortalidad global: 6.9%.

**Redundancia:** tres pares de indicadores son idénticos (mismo panel químico
o misma regla de ≥3 fechas), así que hay 7 patrones únicos. El indicador de
eGFR difiere del de creatinina en 57 personas.

**Decisión:** Los indicadores de albúmina, creatinina y eGFR son los
informativos (mortalidad 2.7–3.7% vs 6.9% global); los de PAS, IMC y albúmina
última tienen muy pocos casos y aportan poco.



## Actividad 9.

Script `imputacion.py`. Imputación dentro de un `Pipeline`, seguida de `StandardScaler` y regresión logística
(`class_weight="balanced"`). Validación cruzada estratificada de 5 pliegues
(`random_state=42`). X = 34 variables numéricas; 369 eventos en 5,372.
Prevalencia (AUPRC de referencia al azar): 0.069.

| Estrategia | AUROC (media ± DE) | AUPRC (media ± DE) |
|---|---|---|
| A. Mediana (`SimpleImputer`) | 0.796 ± 0.021 | 0.202 ± 0.018 |
| B. Mediana + indicador (`add_indicator=True`) | **0.807 ± 0.023** | **0.227 ± 0.031** |
| C. Iterativa (`IterativeImputer`, 10 iteraciones) | 0.793 ± 0.026 | 0.204 ± 0.022 |

**Veredicto:** se adopta la estrategia **B**. Mejora AUROC (+0.011) y AUPRC
(+0.025, ~12% relativo) frente a A. 


