import duckdb, os, time, statistics

con = duckdb.connect(os.path.expanduser('~/s12-omop-cdm-introduccion/omop.duckdb'), read_only=True)
# Version 1. una subconsulta sobre un concept_ancestor
v1 = """
SELECT count(DISTINCT person_id) FROM condition_occurrence
WHERE condition_concept_id IN (
    SELECT descendant_concept_id FROM concept_ancestor WHERE ancestor_concept_id = 4182210)
"""

# Versión 2: materializar el concept set en una tabla temporal con índice
con.sql("CREATE TEMP TABLE cs_demencia AS SELECT descendant_concept_id AS concept_id FROM concept_ancestor WHERE ancestor_concept_id = 4182210")
con.sql("CREATE INDEX idx_cs ON cs_demencia(concept_id)")

v2 = """
SELECT count(DISTINCT co.person_id) FROM condition_occurrence co
JOIN cs_demencia cs ON cs.concept_id = co.condition_concept_id
"""

for nombre, q in [("V1 IN subconsulta", v1), ("V2 tabla + JOIN", v2)]:
    tiempos = []
    for i in range(3):
        t0 = time.perf_counter()
        r = con.sql(q).fetchall()
        tiempos.append((time.perf_counter() - t0) * 1000)
    print(f"{nombre}: resultado={r[0][0]} tiempos_ms={[round(t, 1) for t in tiempos]} mediana={statistics.median(tiempos):.1f} ms")

for nombre, q in [("V1", v1), ("V2", v2)]:
    print(f"\n===== PLAN {nombre} =====")
    print(con.sql("EXPLAIN ANALYZE " + q).fetchall()[0][1])
