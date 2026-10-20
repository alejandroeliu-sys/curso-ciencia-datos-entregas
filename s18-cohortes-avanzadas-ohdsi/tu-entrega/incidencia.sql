-- Actividad 5a: entradas a la cohorte 1701 por año calendario
SELECT YEAR(cohort_start_date) AS anio,
       COUNT(*) AS pacientes
FROM results.cohort
WHERE cohort_definition_id = 1701
GROUP BY anio
ORDER BY anio;

-- Actividad 5b: entradas por grupo de edad a la fecha índice
WITH edades AS (
  SELECT c.subject_id,
         YEAR(c.cohort_start_date) - p.year_of_birth AS edad
  FROM results.cohort c
  JOIN person p ON p.person_id = c.subject_id
  WHERE c.cohort_definition_id = 1701
)
SELECT CASE
         WHEN edad BETWEEN 65 AND 69 THEN '65-69'
         WHEN edad BETWEEN 70 AND 74 THEN '70-74'
         WHEN edad BETWEEN 75 AND 79 THEN '75-79'
         WHEN edad BETWEEN 80 AND 84 THEN '80-84'
         ELSE '>=85'
       END AS grupo_edad,
       COUNT(*) AS pacientes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS porcentaje
FROM edades
GROUP BY grupo_edad
ORDER BY grupo_edad;
