# Actividad 5. Índice validado: eGFR CKD-EPI 2021

**Referencia:** Inker LA, Eneanya ND, Coresh J, et al. New Creatinine- and
Cystatin C-Based Equations to Estimate GFR without Race. *N Engl J Med*
2021;385:1737-1749. doi:10.1056/NEJMoa2102953

**Fórmula:** eGFR = 142 × min(Cr/κ, 1)^α × max(Cr/κ, 1)^-1.200 × 0.9938^edad × 1.012 [mujer]
- Mujer: κ = 0.7, α = -0.241. Hombre: κ = 0.9, α = -0.302.
- Cr = última creatinina sérica (mg/dL) en [-365, -1]; edad al índice.
- **Código:** columna `egfr_ckdepi2021` en `build_features.sql`.
- **Regla de calidad:** solo se calcula con creatinina entre 0.2 y 20 mg/dL;
  valores fuera quedan nulos.

## Distribución (N = 5,372; 11.5% faltante)
Mediana 59.5 (RIC 18.3-91.8); mínimo 1.7; máximo 108.4 mL/min/1.73 m².

| Estadio KDIGO | n | Muertes | Tasa de muerte |
|---|---|---|---|
| G5 <15 | 635 | 30 | 4.7% |
| G4 15-29 | 1,469 | 87 | 5.9% |
| G3b 30-44 | 127 | 14 | 11.0% |
| G3a 45-59 | 158 | 10 | 6.3% |
| G2 60-89 | 875 | 81 | 9.3% |
| G1 ≥90 | 1,489 | 125 | 8.4% |

Figura: `figuras/egfr_distribucion.png`

## Interpretación y limitación
- La distribución es bimodal y poco plausible desde el punto de vista clínico: 44% en G4-G5, cuando en adultos
  mayores se espera una cifra menor.
- La mortalidad no aumenta al bajar el eGFR (gradiente inverso al esperado).
- Conclusión: cálculo correcto, pero la creatinina sintética de Synthea
  no refleja la función renal real esperada. Se conserva la variable por
  reproducibilidad. Se espera que la validación en MIMIC-IV Demo permitirá
  evaluar el índice con datos reales.
