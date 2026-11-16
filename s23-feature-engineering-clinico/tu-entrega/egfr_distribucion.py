import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("features.csv")
e = df["egfr_ckdepi2021"]

print(e.describe(percentiles=[0.25, 0.5, 0.75]).round(1))
print(f"% faltante: {e.isna().mean():.1%}")

# Estadios KDIGO por eGFR
cortes = [0, 15, 30, 45, 60, 90, float("inf")]
etiquetas = ["G5 <15", "G4 15-29", "G3b 30-44", "G3a 45-59", "G2 60-89", "G1 >=90"]
df["estadio"] = pd.cut(e, bins=cortes, labels=etiquetas, right=False)
tabla = df.groupby("estadio", observed=False).agg(
    n=("muerte_90d", "size"), muertes=("muerte_90d", "sum"))
tabla["tasa_muerte_%"] = (tabla.muertes / tabla.n * 100).round(1)
print(tabla)

fig, ax = plt.subplots(figsize=(7, 4))
ax.hist(e.dropna(), bins=40, color="steelblue", edgecolor="white")
for c in [15, 30, 45, 60, 90]:
    ax.axvline(c, color="grey", ls="--", lw=0.8)
ax.set_xlabel("eGFR CKD-EPI 2021 (mL/min/1.73 m²)")
ax.set_ylabel("Pacientes")
ax.set_title("Distribución de eGFR en la cohorte (N = 5,372)")
fig.tight_layout()
fig.savefig("figuras/egfr_distribucion.png", dpi=150)
print("Figura guardada en figuras/egfr_distribucion.png")
