import pandas as pd
from scipy.stats import chi2_contingency

df = pd.read_csv("features.csv")

# Variables con algún faltante
con_faltantes = [c for c in df.columns if df[c].isna().any()]

filas = []
for v in con_faltantes:
    falta = df[v].isna()
    tabla = pd.crosstab(falta, df["muerte_90d"])
    p = chi2_contingency(tabla)[1]
    filas.append({
        "variable": v,
        "% faltante": round(falta.mean() * 100, 1),
        "muerte % con dato": round(df.loc[~falta, "muerte_90d"].mean() * 100, 1),
        "muerte % sin dato": round(df.loc[falta, "muerte_90d"].mean() * 100, 1),
        "p (chi2)": round(p, 4),
    })

res = pd.DataFrame(filas)
print(res.to_string(index=False))

for v in ["creatinina_ultima", "albumina_pendiente"]:
    falta = df[v].isna()
    print(f"\n=== {v}: medias según falta (False = tiene dato) ===")
    print(df.groupby(falta)[["edad", "n_ambulatorias_365", "n_hosp_365",
                             "n_ingredientes_365", "ic_dx"]].mean().round(2))
