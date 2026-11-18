# Laboratorio 24: comparación de modelos y veredicto

Cohorte 1701 (5,372 casos completos; 143 censurados excluidos,actividad 7).
Desenlace: muerte en días [1, 90] tras el egreso. Partición temporal 80/20 .
Entrenamiento: 4,296 (306 muertes, 7.1 %). Prueba: 1,076 (63 muertes, 5.9 %). Semilla 42.

## Actividad 11. Tabla comparativa

AUROC y AUPRC: predicciones fuera del pliegue (CV estratificada de 5 pliegues en entrenamiento) con IC 95 % por bootstrap (1,000 remuestreos).
Tiempo: suma del ajuste en los 5 pliegues (actividad 1); para el modelo ajustado se suma la búsqueda de Optuna.

| Modelo | AUROC (IC 95 %) | AUPRC (IC 95 %) | Tiempo de entrenamiento | Explicabilidad |
|---|---|---|---|---|
| Dummy (prior) | 0.499 (0.476–0.520) | 0.071 (0.063–0.079) | 0.05 s | Total (predice la prevalencia) |
| Regresión logística (C = 1) | 0.791 (0.762–0.818) | 0.217 (0.184–0.259) | 0.09 s | Alta: coeficientes y odds ratios |
| k-NN (k = 25) | 0.776 (0.747–0.805) | 0.233 (0.196–0.281) | 0.08 s | Baja |
| SVM (RBF) | 0.723 (0.688–0.758) | 0.280 (0.235–0.343) | 0.54 s | Muy baja |
| Random Forest (500 árboles) | 0.831 (0.803–0.857) | 0.414 (0.357–0.474) | 4.08 s | Media |
| XGBoost (300, por defecto) | 0.801 (0.773–0.829) | 0.363 (0.311–0.418) | 4.61 s | Media|
| LightGBM (300, por defecto) | 0.810 (0.781–0.836) | 0.370 (0.316–0.431) | 1.11 s | Media |
| **LightGBM (ajustado con Optuna)** | **0.839 (0.811–0.867)** | **0.442 (0.386–0.500)** | ~30 s de búsqueda (100 trials) + < 1 s | Media |

**Estimaciones del LightGBM ajustado:**

| Estimación | AUROC |
|---|---|
| CV simple (mejor de 100 trials) | 0.842 |
| CV anidada (5 externos × 30 trials internos) | **0.826 ± 0.016** |
| Prueba, una sola vez | 0.881 (0.840–0.918); AUPRC 0.305 (0.213–0.416) |

## Actividad 12. Veredicto: ¿la complejidad valió la pena?

**Sobre la regresión logística, sí, pero sobre el Random Forest sin ajustar, no.** Frente a la regresión logística, los modelos de árboles ganan alrededor de 0.04 de AUROC (0.831 a 0.839 contra 0.791). La ganancia grande está en el AUPRC: 0.41 a 0.44 contra 0.22, sin traslape de intervalos. Los árboles identifican mucho mejor a los pacientes de mayor riesgo.
En cambio, el LightGBM ajustado con Optuna (0.839) **no se distingue** del Random Forest con hiperparámetros por defecto (0.831): la diferencia de 0.008 es mucho menor que el ancho de los intervalos (~0.055). La estimación honesta del ajustado (CV anidada, 0.826) incluso queda por debajo del Random Forest. Los 100 trials sí mejoraron a LightGBM frente a su configuración por defecto (0.810 a 0.826 anidado), pero solo lo llevaron al nivel que el Random Forest alcanza sin ajustar. El 0.881 en prueba no cambia la conclusión: con 63 muertes, su intervalo es amplio, y el rendimiento esperado que reporto es el de la CV anidada.

**Recomendación:** para esta cohorte, un **Random Forest con parámetros por defecto** o el LightGBM ajustado son equivalentes en discriminación. Elijo el **LightGBM ajustado como modelo final** porque entrena más rápido y está documentado de principio a fin (espacio de búsqueda, CV anidada, prueba única), pero no es superior. Con 306 eventos, la optimización de hiperparámetros dio una ganancia real pequeña. 
