# Espacio de búsqueda de Optuna (LightGBM)

Modelo: LGBMClassifier dentro del mismo Pipeline . Datos: entrenamiento temporal (4,296 personas, 306 muertes). Métrica a optimizar: AUROC medio en CV estratificada de 5 pliegues, con SEMILLA = 42. El número de árboles no se busca: lo fija el early stopping (techo de 2000, paciencia de 50), como en la actividad 4.

| Parámetro | Rango | Escala | 
|---|---|---|---|
| learning_rate | 0.01 a 0.2 | log-uniforme | 
| max_depth | 2 a 6 | entera | 
| num_leaves | 4 a 31 | entera, limitada a menos de 2^max_depth | 
| min_child_samples (el equivalente de min_child_weight en LightGBM) | 10 a 100 | entera | 
| subsample | 0.6 a 1.0 | uniforme (con subsample_freq=1) |
| colsample_bytree | 0.5 a 1.0 | uniforme | 
| reg_lambda | 0.001 a 10 | log-uniforme | 

**Lo que no se busca, y por qué:** n_estimators (lo decide el early stopping), reg_alpha (L1; con unas 50 columnas no hace falta selección de variables y añadiría una dimensión con poco efecto) y class_weight / scale_pos_weight (no cambian el orden de las predicciones, que es lo que miden AUROC y AUPRC).

**Por qué un espacio estrecho:** solo unos pocos hiperparámetros importan de verdad. Rangos amplios, como learning_rate entre 0.0001 y 1, gastan la mitad de las pruebas en configuraciones absurdas. Rangos razonados, con escala log donde el efecto es multiplicativo, aprovechan mejor los 100 trials.
