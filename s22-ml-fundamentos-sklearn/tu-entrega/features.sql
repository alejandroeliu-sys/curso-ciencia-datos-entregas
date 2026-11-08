WITH fin AS (
  SELECT MAX(observation_period_end_date) AS fecha_fin FROM observation_period
),
coh AS (
  SELECT co.subject_id AS person_id, co.cohort_start_date AS fecha_indice
  FROM results.cohort co, fin
  WHERE co.cohort_definition_id = 1701
    AND co.cohort_start_date + INTERVAL 90 DAY <= fin.fecha_fin
),
dx AS (
  SELECT c.person_id,
         MAX(CASE WHEN ca.ancestor_concept_id = 201826   THEN 1 ELSE 0 END) AS dm2_prev,
         MAX(CASE WHEN ca.ancestor_concept_id = 316139   THEN 1 ELSE 0 END) AS ic_prev,
         MAX(CASE WHEN ca.ancestor_concept_id = 46271022 THEN 1 ELSE 0 END) AS erc_prev,
         MAX(CASE WHEN ca.ancestor_concept_id = 4182210  THEN 1 ELSE 0 END) AS demencia_prev
  FROM coh c
  JOIN condition_occurrence o ON o.person_id = c.person_id
   AND o.condition_start_date <= c.fecha_indice - INTERVAL 1 DAY
  JOIN concept_ancestor ca ON ca.descendant_concept_id = o.condition_concept_id
   AND ca.ancestor_concept_id IN (201826, 316139, 46271022, 4182210)
  GROUP BY c.person_id
),
lab AS (
  SELECT c.person_id, m.measurement_concept_id, m.value_as_number,
         ROW_NUMBER() OVER (PARTITION BY c.person_id, m.measurement_concept_id
                            ORDER BY m.measurement_date DESC) AS rn
  FROM coh c
  JOIN measurement m ON m.person_id = c.person_id
   AND m.measurement_date BETWEEN c.fecha_indice - INTERVAL 365 DAY AND c.fecha_indice
   AND m.measurement_concept_id IN (3016723, 3000963)
   AND m.value_as_number IS NOT NULL
)
SELECT c.person_id,
       c.fecha_indice,
       YEAR(c.fecha_indice) - p.year_of_birth                AS edad,
       CASE WHEN p.gender_concept_id = 8507 THEN 1 ELSE 0 END AS sexo_masc,
       COALESCE(dx.dm2_prev, 0)      AS dm2_prev,
       COALESCE(dx.ic_prev, 0)       AS ic_prev,
       COALESCE(dx.erc_prev, 0)      AS erc_prev,
       COALESCE(dx.demencia_prev, 0) AS demencia_prev,
       MAX(CASE WHEN l.measurement_concept_id = 3016723 THEN l.value_as_number END) AS creatinina,
       MAX(CASE WHEN l.measurement_concept_id = 3000963 THEN l.value_as_number END) AS hemoglobina,
       CASE WHEN d.death_date BETWEEN c.fecha_indice + INTERVAL 1 DAY
                                  AND c.fecha_indice + INTERVAL 90 DAY THEN 1 ELSE 0 END AS muerte_90d,
       CASE WHEN d.death_date BETWEEN c.fecha_indice + INTERVAL 1 DAY
                                  AND c.fecha_indice + INTERVAL 90 DAY
            THEN DATE_DIFF('day', c.fecha_indice, d.death_date) ELSE 90 END AS dias_seguimiento
FROM coh c
JOIN person p ON p.person_id = c.person_id
LEFT JOIN dx ON dx.person_id = c.person_id
LEFT JOIN lab l ON l.person_id = c.person_id AND l.rn = 1
LEFT JOIN death d ON d.person_id = c.person_id
GROUP BY ALL;
