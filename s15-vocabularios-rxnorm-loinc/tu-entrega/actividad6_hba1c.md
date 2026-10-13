# Actividad 6 – Concept set de HbA1c

| concept_id | Código LOINC | Nombre | Mediciones |
|---|---|---|---|
| 3004410 | 4548-4 | Hemoglobin A1c/Hemoglobin.total in Blood | 42,422 |

**Comparación:** usar solo el 4548-4 captura 42,422 mediciones; el concept set ampliado (incluyendo variantes como 59261-8, método IFCC) captura 42,422 registros, es decir 0 adicionales.

**Interpretación:** Synthea registra todas las HbA1c con un solo código LOINC, por eso ambas definiciones coinciden. En un hospital real, cada laboratorio puede usar códigos distintos según su método; si solo usara el 4548-4, perdería las mediciones registradas con otros códigos.
