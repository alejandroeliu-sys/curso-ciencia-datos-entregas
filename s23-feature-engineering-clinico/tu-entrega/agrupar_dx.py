import duckdb

BASE = "/home/alecedillo/s12-omop-cdm-introduccion/omop_20k.duckdb"
con = duckdb.connect(BASE, read_only=True)
df = __import__("pandas").read_csv("features.csv", parse_dates=["fecha_indice"])
con.register("coh", df[["person_id", "fecha_indice"]])

# Diagnósticos de la cohorte en (-inf, -1]
con.execute("""
CREATE TEMP TABLE dx AS
SELECT DISTINCT o.person_id, o.condition_concept_id AS cid
FROM coh c
JOIN condition_occurrence o
  ON o.person_id = c.person_id
 AND o.condition_start_date <= c.fecha_indice - INTERVAL 1 DAY
WHERE o.condition_concept_id <> 0
""")
n_conceptos = con.execute("SELECT COUNT(DISTINCT cid) FROM dx").fetchone()[0]
print("Conceptos de diagnóstico distintos:", n_conceptos)

for nivel in [1, 2]:
    r = con.execute(f"""
    WITH cat AS (            -- categorías: descendientes de 'Disease' a ese nivel
      SELECT descendant_concept_id AS cat_id
      FROM concept_ancestor
      WHERE ancestor_concept_id = 4274025
        AND min_levels_of_separation = {nivel}
    ),
    mapa AS (                -- cada diagnóstico -> sus categorías
      SELECT DISTINCT dx.person_id, dx.cid, cat.cat_id
      FROM dx
      JOIN concept_ancestor ca ON ca.descendant_concept_id = dx.cid
      JOIN cat ON cat.cat_id = ca.ancestor_concept_id
    )
    SELECT COUNT(DISTINCT cat_id)              AS categorias,
           COUNT(DISTINCT cid)                 AS conceptos_cubiertos,
           COUNT(DISTINCT cat_id) FILTER (WHERE TRUE) AS dummy
    FROM mapa
    """).fetchone()
    print(f"\nNivel {nivel}: {r[0]} categorías; "
          f"cubre {r[1]} de {n_conceptos} conceptos ({r[1]/n_conceptos:.0%})")

    top = con.execute(f"""
    WITH cat AS (
      SELECT descendant_concept_id AS cat_id FROM concept_ancestor
      WHERE ancestor_concept_id = 4274025 AND min_levels_of_separation = {nivel}
    )
    SELECT c.concept_name AS categoria, COUNT(DISTINCT dx.person_id) AS pacientes
    FROM dx
    JOIN concept_ancestor ca ON ca.descendant_concept_id = dx.cid
    JOIN cat ON cat.cat_id = ca.ancestor_concept_id
    JOIN concept c ON c.concept_id = cat.cat_id
    GROUP BY c.concept_name
    ORDER BY pacientes DESC
    LIMIT 15
    """).df()
    print(top.to_string(index=False))

# Criterio final: nivel 2
N = len(df)
prev = con.execute("""
WITH cat AS (
  SELECT descendant_concept_id AS cat_id FROM concept_ancestor
  WHERE ancestor_concept_id = 4274025 AND min_levels_of_separation = 2
)
SELECT c.concept_name AS categoria, COUNT(DISTINCT dx.person_id) AS pacientes
FROM dx
JOIN concept_ancestor ca ON ca.descendant_concept_id = dx.cid
JOIN cat ON cat.cat_id = ca.ancestor_concept_id
JOIN concept c ON c.concept_id = cat.cat_id
GROUP BY c.concept_name
""").df()
prev["prevalencia_%"] = (prev.pacientes / N * 100).round(1)
utiles = prev[prev["prevalencia_%"].between(5, 95)].sort_values("pacientes", ascending=False)
print(f"\nCategorías nivel 2 con prevalencia 5-95%: {len(utiles)} de {len(prev)}")
print(utiles.to_string(index=False))
utiles.to_csv("categorias_dx_nivel2.csv", index=False)
