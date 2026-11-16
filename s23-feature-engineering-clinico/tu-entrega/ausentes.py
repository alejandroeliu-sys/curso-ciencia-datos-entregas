# Actividad 8: 
from pathlib import Path
import pandas as pd

df = pd.read_csv("features.csv")
N = len(df)

con_faltantes = [c for c in df.columns if df[c].isna().any()]

resumen = []
for col in con_faltantes:
    nombre = f"{col}_ausente"
    df[nombre] = df[col].isna().astype(int)
    resumen.append({
        "indicador": nombre,
        "n_ausente": int(df[nombre].sum()),
        "pct_ausente": round(100 * df[nombre].mean(), 1),
        "muerte_pct_si_ausente": round(100 * df.loc[df[nombre] == 1, "muerte_90d"].mean(), 1),
    })

tabla = pd.DataFrame(resumen).sort_values("pct_ausente", ascending=False)
print(f"N = {N}; indicadores creados: {len(tabla)}")
print(tabla.to_string(index=False))

# Indicadores con patrón redundante
ind = tabla["indicador"].tolist()
for i, a in enumerate(ind):
    for b in ind[i + 1:]:
        if (df[a] == df[b]).all():
            print(f"Idénticos: {a} = {b}")

df.to_csv("features_con_ausentes.csv", index=False)
print("Guardado features_con_ausentes.csv con", df.shape)
