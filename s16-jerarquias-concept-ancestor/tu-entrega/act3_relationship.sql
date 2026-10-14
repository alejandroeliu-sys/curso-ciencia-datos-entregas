-- Actividad 3.1: tipos de relación y cuántos son jerárquicos o definen ancestros
SELECT count(*) AS total_relaciones,
       sum(CASE WHEN is_hierarchical = '1' THEN 1 ELSE 0 END) AS jerarquicas,
       sum(CASE WHEN defines_ancestry = '1' THEN 1 ELSE 0 END) AS definen_ancestros,
       sum(CASE WHEN is_hierarchical = '1' AND defines_ancestry = '1' THEN 1 ELSE 0 END) AS ambas
FROM relationship;
