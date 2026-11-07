import os, time, duckdb
B = os.environ.get("BUCKET", "fragilidad-datalake-ace-2026")
t = time.time()
con = duckdb.connect()
con.sql("INSTALL httpfs; LOAD httpfs; INSTALL aws; LOAD aws;")
con.sql("CREATE SECRET (TYPE s3, PROVIDER credential_chain, REGION 'us-east-2');")
con.sql(f"""COPY (SELECT anio, ENCOUNTERCLASS, count(*) n
  FROM read_parquet('s3://{B}/staging/synthea/encounters/*/*.parquet', hive_partitioning=true)
  GROUP BY 1,2 ORDER BY 1,2)
  TO 's3://{B}/results/encuentros_por_anio.csv' (HEADER)""")
print(f"Listo en {time.time()-t:.1f} s -> s3://{B}/results/encuentros_por_anio.csv")
