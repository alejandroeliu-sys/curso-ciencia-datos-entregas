import pandas as pd

df = pd.read_csv("features.csv")

# 1) Rangos de variables continuas
continuas = ["edad", "albumina_ultima", "creatinina_ultima", "urea_ultima",
             "pas_ultima", "imc_ultimo", "estancia_indice_dias",
             "n_ingredientes_365", "n_hosp_365"]
print(df[continuas].describe(percentiles=[0.01, 0.5, 0.99]).T.round(2))

# 2) Actividad 4
pares = [("dm_inferida", "dm2_dx"), ("hta_inferida", "hta_dx"),
         ("ic_inferida", "ic_dx"), ("dislipidemia_inferida", "dislipidemia_dx")]
for inf, dx in pares:
    print(f"\n=== {inf} vs {dx} ===")
    print(pd.crosstab(df[inf], df[dx], margins=True))
    solo_inf = ((df[inf] == 1) & (df[dx] == 0)).sum()
    print(f"Captados SOLO por fármacos (sin diagnóstico): {solo_inf}")
