import duckdb
from pathlib import Path

BASE = "/home/alecedillo/s12-omop-cdm-introduccion/omop_20k.duckdb"
SQL = Path("build_features.sql").read_text(encoding="utf-8")

con = duckdb.connect(BASE, read_only=True)
df = con.execute(SQL).df()
df.to_csv("features.csv", index=False)

print("Dimensiones (filas, columnas):", df.shape)
print("Muertes a 90 días:", int(df.muerte_90d.sum()),
      f"({df.muerte_90d.mean():.1%})")
print("\n% faltante por columna:")
print((df.isna().mean() * 100).round(1).to_string())
