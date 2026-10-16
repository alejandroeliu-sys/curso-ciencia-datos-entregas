-- Estimación del tamaño de muestra, criterio por criterio (sin muerte)
WITH egresos AS (            -- hospitalizaciones a los 65 años o más
  SELECT v.person_id, v.visit_start_date, v.visit_end_date AS fecha_indice,
         ROW_NUMBER() OVER (PARTITION BY v.person_id ORDER BY v.visit_end_date) AS n
  FROM visit_occurrence v
  JOIN person p ON p.person_id = v.person_id
  WHERE v.visit_concept_id = 9201
    AND YEAR(v.visit_end_date) - p.year_of_birth >= 65
),
indice AS (SELECT * FROM egresos WHERE n = 1),   -- primer egreso
paso AS (
  SELECT i.person_id,
    EXISTS (SELECT 1 FROM measurement m WHERE m.person_id = i.person_id
            AND m.measurement_concept_id IN (3051825, 3016723)
            AND m.measurement_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice) AS creatinina,
    EXISTS (SELECT 1 FROM measurement m WHERE m.person_id = i.person_id
            AND m.measurement_concept_id = 3024561
            AND m.measurement_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice) AS albumina,
    EXISTS (SELECT 1 FROM measurement m WHERE m.person_id = i.person_id
            AND m.measurement_concept_id = 46236952
            AND m.measurement_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice) AS tfg,
    (SELECT COUNT(*) FROM visit_occurrence v2 WHERE v2.person_id = i.person_id
            AND v2.visit_concept_id = 9202
            AND v2.visit_start_date BETWEEN i.fecha_indice - INTERVAL 365 DAY AND i.fecha_indice) >= 2 AS dos_visitas
  FROM indice i
)
SELECT
  COUNT(*)                                                    AS con_egreso_65,
  SUM(CASE WHEN dos_visitas THEN 1 ELSE 0 END)                AS mas_2_visitas,
  SUM(CASE WHEN dos_visitas AND creatinina THEN 1 ELSE 0 END) AS mas_creatinina,
  SUM(CASE WHEN dos_visitas AND creatinina AND albumina THEN 1 ELSE 0 END) AS mas_albumina,
  SUM(CASE WHEN dos_visitas AND creatinina AND albumina AND tfg THEN 1 ELSE 0 END) AS mas_tfg
FROM paso;
