# Actividad 4. 

Ventana: [-365, -1] respecto al egreso índice. Cada registro se lleva a su
ingrediente con CONCEPT_ANCESTOR (concept_class_id = 'Ingredient').
Regla : el ingrediente debe aparecer en al menos 2 fechas distintas,
para exigir uso sostenido.

| Variable | Ingredientes (concept_id) | Regla |
|---|---|---|
| `dm_inferida` | metformina 1503297, insulina regular 1596977, insulina isófana 46221581 | ≥2 fechas distintas con cualquiera |
| `hta_inferida` | lisinopril 1308216, hidroclorotiazida 974166, amlodipino 1332418, losartán 1367500 | ≥2 fechas distintas con cualquiera |
| `ic_inferida` | furosemida 956874 + (carvedilol 1346823 o metoprolol 1307046) | furosemida en ≥2 fechas y ≥1 betabloqueador |
| `dislipidemia_inferida` | simvastatina 1539403 | ≥2 fechas distintas |

## Inferida vs diagnóstico codificado (N = 5,372)

| Inferida | Diagnóstico | Inferida = 1 | Ambas | Solo fármacos | Solo diagnóstico |
|---|---|---|---|---|---|
| `dm_inferida` | `dm2_dx` (201826) | 1,560 | 682 | **878** | 494 |
| `hta_inferida` | `hta_dx` (320128) | 2,214 | 2,060 | **154** | 1,180 |
| `ic_inferida` | `ic_dx` (316139) | 543 | 543 | **0** | 464 |
| `dislipidemia_inferida` | `dislipidemia_dx` (432867) | 428 | 426 | **2** | 2,493 |

## Interpretación
- **Diabetes:** los fármacos captan 878 pacientes sin diagnóstico. 
- **Hipertensión:** suma 154. 
- **Insuficiencia cardiaca y dislipidemia:** casi no suman pacientes, 2 en total por ambas condiciones; 

