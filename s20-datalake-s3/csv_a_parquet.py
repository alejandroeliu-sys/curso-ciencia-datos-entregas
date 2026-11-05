"""raw: CSV originales de Synthea -> staging: Parquet particionado por año (DuckDB)."""
import os, time, pathlib
import duckdb
import s3util as u

B = "fragilidad-datalake-ace-2026"
CSV = pathlib.Path.home() / "synthea/output/csv"
OUT = pathlib.Path("parquet_local")
s3 = u.cliente()

# tabla: columna de fecha para la partición
TABLAS = {"patients": "BIRTHDATE", "encounters": "START", "conditions": "START"}

con = duckdb.connect()
con.execute("SET memory_limit='12GB'")

for t, fecha in TABLAS.items():
    f = CSV / f"{t}.csv"
    # 1) raw: CSV tal cual
    t0 = time.time()
    u.subir(s3, f, B, f"raw/synthea/{t}.csv")
    print(f"raw/{t}.csv subido ({f.stat().st_size/1e6:.0f} MB, {time.time()-t0:.0f} s)")

    # 2) Parquet particionado por año
    destino = OUT / t
    con.execute(f"""
        COPY (SELECT *, year(CAST("{fecha}" AS DATE)) AS anio FROM read_csv('{f}', header=true))
        TO '{destino}' (FORMAT parquet, PARTITION_BY (anio), COMPRESSION zstd, OVERWRITE_OR_IGNORE)
    """)

    # 3) staging: subir cada archivo conservando la ruta anio=XXXX/
    archivos = list(destino.rglob("*.parquet"))
    for p in archivos:
        u.subir(s3, p, B, f"staging/synthea/{t}/{p.relative_to(destino)}")
    mb = sum(p.stat().st_size for p in archivos) / 1e6
    print(f"staging/{t}: {len(archivos)} archivos Parquet, {mb:.0f} MB")

print("Objetos en staging:", len(u.listar(s3, B, "staging/")))
