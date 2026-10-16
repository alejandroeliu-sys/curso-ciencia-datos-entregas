# Tabla de atrición – Cohorte 1701

| paso                                              |   N | % que queda | se perdieron |
|---------------------------------------------------|-----|-------------|--------------|
| con el evento inicial (primer egreso a los 65 años o más)   | 411 | 100.0 %     | —            |
| + 730 días de observación previa (dos años)                  | 411 | 100.0 %     | 0            |
| + lavado (sin hospitalización en 30 días previo por reingresos) | 409 |  99.5 %     | 2            |
| + inclusión 1: 2 visitas ambulatorias o más       | 331 |  80.5 %     | 78           |
| + inclusión 2: creatinina                         | 293 |  71.3 %     | 38           |
| + inclusión 3: albúmina sérica                    | 223 |  54.3 %     | 70           |
| + inclusión 4: tasa de filtración glomerular      | 223 |  54.3 %     | 0            |
| + inclusión 5: multimorbilidad                    | 223 |  54.3 %     | 0            |
| − exclusión 2: cáncer maligno                     | 196 |  47.7 %     | 27           |
| **cohorte final**                                 | **196** | **47.7 %** | **215** |

Exclusión 1 (muerte el día del egreso o antes): pendiente, porque la base no tiene tabla `death`, ello se obtendra posteriormente con la base patients.csv.

## ¿Qué criterio costó más y vale la pena?

El criterio más costoso fue la inclusión 1, al menos 2 visitas ambulatorias en el año previo, que quitó 78 pacientes (19 % de los que quedaban). Le sigue la albúmina sérica, con 70 (24 % de los que quedaban). Las 2 visitas valen la pena: sin contacto previo con el sistema de salud no hay diagnósticos con qué calcular el HFRS, que es la base del proyecto. El costo de la albúmina es más discutible. Es una variable predictora y no un requisito para definir a la población, exigirla podría generar sesgo de selección. Una alternativa es quitarla como criterio y manejarla como dato faltante en el modelo; eso dejaría 293 pacientes antes de la exclusión por cáncer. La observación previa no quitó a nadie por el artefacto de Synthea (un periodo de unos 28.7 años por persona), y la gráfica `primeros_egresos_por_anio.png` no muestra pico de arranque. La tasa de filtración y la multimorbilidad tampoco quitaron a nadie, porque todos los que tenían albúmina ya las cumplían.

## Seguimiento

La mediana de seguimiento es de 90 días (de 1 a 90). Se eliminaron 23 pacientes antes de los 90 días porque su periodo de observación termina antes.
