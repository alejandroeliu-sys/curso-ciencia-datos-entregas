# Justificación del concept set: demencia (degenerativa y de causa vascular)

## Condición y pregunta
Despues de verificar la base generada y los diagnosticos acorde con el vocabulario SNOMED se opto por escoger como condición a demencia debido a que es el ítem al cual el HFRS que se utilizara en el proyecto final le otorga mayor puntaje de relevancia, solo se tuvo que revisar los diagnósticos del ICD10 incluidos en el concepto semilla para delimitar más la búsqueda

## Concepto semilla
4182210 Dementia (SNOMED 52448006): Condition, SNOMED, Disorder, estándar y vigente.

## Impacto de cada versión
| Versión | Conceptos | Pacientes | Diferencia contra B |
|---|---:|---:|---:|
| A estricta | 1 | 0 | −100 % |
| B amplia | 216 | 147 | — |
| C razonada (exclusión de algunos subtipos de demencia) | 190 | 116 | −21.1 % |

Revisión manual: 20 descendientes tomados al azar con semilla fija (hash del concept_id + 'semilla42'); 10 falsos positivos (50 %) acorde con nuestra búsqueda razonada.

## Decisiones
| concept_id | nombre | incluido | por qué |
|---|---|---|---|
| 374341 | Huntington's chorea | No | condición con mutación genética, con predisposición de nacimiento y otras manifestaciones |
| 4047752 | Late onset Huntington's disease | No | misma justificación que corea de Huntington  |
| 4182539 | Alzheimer type, presenile onset, with delusions | No | no es en adultos mayores, si no una condición en personas más jóvenes, con peor pronóstico  |
| 4019705 | Alzheimer type, presenile onset, with depression | No | no es en adultos mayores, si no una condición en personas más jóvenes, con peor pronóstico  |
| 37204554 | ADan amyloidosis | No | una causa diferente de demencia, con otras manifestaciones  |
| 37162253 | ITM2B-related amyloidosis | No | demencia como un síntoma de una enfermedad más sistémica  |
| 37166530 | Atypical pantothenate kinase associated neurodegeneration | No | con predisposición de riesgo de nacimiento  |
| 42538609 | Dementia due to prion disease | No | causa adquirida, con otras manifestaciones  |
| 37166361 | Dementia due to Lyme disease | No | causa infecciosa no degenerativa  |
| 37166338 | Dementia due to Hashimoto encephalopathy | No | de origen metabólico  |
| (SNOMED 230265002) | Familial Alzheimer's disease of early onset | No | condiciómn en personas más jóvenes  |
| 4047744 | Pick's disease with Pick bodies | Sí | puede presentarse de inicio más temprano y se asocia a otras síntomas, con peor pronóstico |
| 4047748 | Patchy dementia | Sí | presentación no habitual de demnencias de tipo vascular, con evolución más tórpida |

## Sensibilidad y valor predictivo positivo
A mi parecer la demencia como concepto semilla incluye un espectro de enfermedades con orígenes muy diferentes y con diferentes evoluciones y pronóstico, por lo cual delimitar nuestra búisqueda a causas degenerativas o vasculares solo en personas mayores, delimita mejor el fenómeno de estudio, lo que puede mejorar las métricas asociadas a precisión del modelo.El costo es una menor sensibilidad: pasamos de 147 a 116 pacientes, así que podríamos perder algunos casos reales de demencia que quedaron registrados con un código excluido
