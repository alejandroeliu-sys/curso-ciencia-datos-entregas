--Matriz de features del proyecto 

WITH coh AS (
  -- Cohorte
  SELECT co.subject_id                   AS person_id,
         co.cohort_start_date            AS fecha_indice,
         op.observation_period_start_date AS obs_inicio,
         d.death_date
  FROM results.cohort co
  JOIN observation_period op
    ON op.person_id = co.subject_id
   AND co.cohort_start_date BETWEEN op.observation_period_start_date
                                AND op.observation_period_end_date
  LEFT JOIN death d ON d.person_id = co.subject_id
  WHERE co.cohort_definition_id = 1701
    AND (d.death_date IS NULL OR d.death_date > co.cohort_start_date)
    AND (d.death_date <= co.cohort_start_date + INTERVAL 90 DAY
         OR op.observation_period_end_date >= co.cohort_start_date + INTERVAL 90 DAY)
),

-- PERSON
persona AS (
  SELECT c.person_id,
         FLOOR(DATE_DIFF('day', CAST(p.birth_datetime AS DATE), c.fecha_indice) / 365.25) AS edad,
         CASE WHEN p.gender_concept_id = 8507 THEN 1 ELSE 0 END AS sexo_masc,
         DATE_DIFF('day', c.obs_inicio, c.fecha_indice)          AS obs_previa_dias
  FROM coh c
  JOIN person p ON p.person_id = c.person_id
),

-- CONDITION_OCCURRENCE
dx AS (
  SELECT c.person_id,
         MAX(CASE WHEN ca.ancestor_concept_id = 201826   THEN 1 ELSE 0 END) AS dm2_dx,
         MAX(CASE WHEN ca.ancestor_concept_id = 316139   THEN 1 ELSE 0 END) AS ic_dx,
         MAX(CASE WHEN ca.ancestor_concept_id = 46271022 THEN 1 ELSE 0 END) AS erc_dx,
         MAX(CASE WHEN ca.ancestor_concept_id = 4182210  THEN 1 ELSE 0 END) AS demencia_dx,
         MAX(CASE WHEN ca.ancestor_concept_id = 4185932  THEN 1 ELSE 0 END) AS cardiop_isq_dx,
         MAX(CASE WHEN ca.ancestor_concept_id = 320128   THEN 1 ELSE 0 END) AS hta_dx,
         MAX(CASE WHEN ca.ancestor_concept_id = 439777   THEN 1 ELSE 0 END) AS anemia_dx,
         MAX(CASE WHEN ca.ancestor_concept_id = 432867 THEN 1 ELSE 0 END) AS dislipidemia_dx
  FROM coh c
  JOIN condition_occurrence o
    ON o.person_id = c.person_id
   AND o.condition_start_date <= c.fecha_indice - INTERVAL 1 DAY
  JOIN concept_ancestor ca
    ON ca.descendant_concept_id = o.condition_concept_id
   AND ca.ancestor_concept_id IN (201826, 316139, 46271022, 4182210, 4185932, 320128, 439777, 432867)  
  GROUP BY c.person_id
),

-- DRUG_EXPOSURE
rx AS (
  SELECT c.person_id,
         x.drug_exposure_start_date AS fecha,
         DATE_DIFF('day', c.fecha_indice, x.drug_exposure_start_date) AS dia,
         ca.ancestor_concept_id AS ingrediente
  FROM coh c
  JOIN drug_exposure x
    ON x.person_id = c.person_id
   AND x.drug_exposure_start_date BETWEEN c.fecha_indice - INTERVAL 365 DAY
                                      AND c.fecha_indice - INTERVAL 1 DAY
  JOIN concept_ancestor ca ON ca.descendant_concept_id = x.drug_concept_id
  JOIN concept i
    ON i.concept_id = ca.ancestor_concept_id
   AND i.concept_class_id = 'Ingredient'
),
farmacos AS (
  SELECT person_id,
         COUNT(DISTINCT ingrediente)                           AS n_ingredientes_365,
         COUNT(DISTINCT ingrediente) FILTER (WHERE dia >= -30) AS n_ingredientes_30,
         -- Comorbilidades inferidas
         CASE WHEN COUNT(DISTINCT fecha) FILTER (
                   WHERE ingrediente IN (1503297, 1596977, 46221581)) >= 2
              THEN 1 ELSE 0 END AS dm_inferida,          
         CASE WHEN COUNT(DISTINCT fecha) FILTER (
                   WHERE ingrediente IN (1308216, 974166, 1332418, 1367500)) >= 2
              THEN 1 ELSE 0 END AS hta_inferida,         
         CASE WHEN COUNT(DISTINCT fecha) FILTER (WHERE ingrediente = 956874) >= 2
               AND COUNT(*) FILTER (WHERE ingrediente IN (1346823, 1307046)) >= 1
              THEN 1 ELSE 0 END AS ic_inferida,
          CASE WHEN COUNT(DISTINCT fecha) FILTER (WHERE ingrediente = 1539403) >= 2
              THEN 1 ELSE 0 END AS dislipidemia_inferida  
  FROM rx
  GROUP BY person_id
),

-- MEASUREMENT
lab AS (
  SELECT c.person_id,
         m.measurement_concept_id AS cid,
         m.value_as_number        AS valor,
         DATE_DIFF('day', c.fecha_indice, m.measurement_date) AS dia,
         ROW_NUMBER() OVER (PARTITION BY c.person_id, m.measurement_concept_id
                            ORDER BY m.measurement_date DESC) AS rn
  FROM coh c
  JOIN measurement m
    ON m.person_id = c.person_id
   AND m.measurement_date BETWEEN c.fecha_indice - INTERVAL 365 DAY
                              AND c.fecha_indice - INTERVAL 1 DAY
   AND m.measurement_concept_id IN (3024561, 3051825, 3004295, 3004249, 3038553)
   AND m.value_as_number IS NOT NULL
),
labs AS (
  SELECT person_id,
         -- Albúmina 
         MAX(valor) FILTER (WHERE cid = 3024561 AND rn = 1) AS albumina_ultima,
         COUNT(*)   FILTER (WHERE cid = 3024561)            AS albumina_n,
         CASE WHEN COUNT(DISTINCT dia) FILTER (WHERE cid = 3024561) >= 3
              THEN REGR_SLOPE(valor, dia / 365.0) FILTER (WHERE cid = 3024561)
         END AS albumina_pendiente,                          -- g/dL por año
         CASE WHEN COUNT(DISTINCT dia) FILTER (WHERE cid = 3024561) >= 3
              THEN STDDEV_SAMP(valor) FILTER (WHERE cid = 3024561)
         END AS albumina_de,
         -- Creatinina 
         MAX(valor) FILTER (WHERE cid = 3051825 AND rn = 1) AS creatinina_ultima,
         COUNT(*)   FILTER (WHERE cid = 3051825)            AS creatinina_n,
         CASE WHEN COUNT(DISTINCT dia) FILTER (WHERE cid = 3051825) >= 3
              THEN REGR_SLOPE(valor, dia / 365.0) FILTER (WHERE cid = 3051825)
         END AS creatinina_pendiente,
       
         -- Urea / BUN 
         MAX(valor) FILTER (WHERE cid = 3004295 AND rn = 1) AS urea_ultima,
         COUNT(*)   FILTER (WHERE cid = 3004295)            AS urea_n,
         CASE WHEN COUNT(DISTINCT dia) FILTER (WHERE cid = 3004295) >= 3
              THEN REGR_SLOPE(valor, dia / 365.0) FILTER (WHERE cid = 3004295)
         END AS urea_pendiente,
         -- Signos: última presión sistólica e IMC 
         MAX(valor) FILTER (WHERE cid = 3004249 AND rn = 1) AS pas_ultima,
         MAX(valor) FILTER (WHERE cid = 3038553 AND rn = 1) AS imc_ultimo
  FROM lab
  GROUP BY person_id
),

-- VISIT_OCCURRENCE: visitas en [-365, -1]
visitas AS (
  SELECT c.person_id,
         COUNT(*) FILTER (WHERE v.visit_concept_id = 9202) AS n_ambulatorias_365,
         COUNT(*) FILTER (WHERE v.visit_concept_id = 9201
                            AND v.visit_end_date <= c.fecha_indice - INTERVAL 1 DAY)
                                                           AS n_hosp_365,
         COUNT(*) FILTER (WHERE v.visit_concept_id = 9203) AS n_urgencias_365
  FROM coh c
  JOIN visit_occurrence v
    ON v.person_id = c.person_id
   AND v.visit_start_date BETWEEN c.fecha_indice - INTERVAL 365 DAY
                              AND c.fecha_indice - INTERVAL 1 DAY
  GROUP BY c.person_id
),

-- Duración de la hospitalización índice 
estancia AS (
  SELECT c.person_id,
         MAX(DATE_DIFF('day', v.visit_start_date, v.visit_end_date)) AS estancia_indice_dias
  FROM coh c
  JOIN visit_occurrence v
    ON v.person_id = c.person_id
   AND v.visit_concept_id = 9201
   AND v.visit_end_date = c.fecha_indice
  GROUP BY c.person_id
)

SELECT c.person_id,
       c.fecha_indice,
       pe.edad, pe.sexo_masc, pe.obs_previa_dias,
       COALESCE(dx.dm2_dx, 0)         AS dm2_dx,
       COALESCE(dx.ic_dx, 0)          AS ic_dx,
       COALESCE(dx.erc_dx, 0)         AS erc_dx,
       COALESCE(dx.demencia_dx, 0)    AS demencia_dx,
       COALESCE(dx.cardiop_isq_dx, 0) AS cardiop_isq_dx,
       COALESCE(dx.hta_dx, 0)         AS hta_dx,
       COALESCE(dx.anemia_dx, 0)      AS anemia_dx,
       COALESCE(dx.dislipidemia_dx, 0) AS dislipidemia_dx,
       COALESCE(f.n_ingredientes_365, 0) AS n_ingredientes_365,
       COALESCE(f.n_ingredientes_30, 0)  AS n_ingredientes_30,
       COALESCE(f.dm_inferida, 0)        AS dm_inferida,
       COALESCE(f.hta_inferida, 0)       AS hta_inferida,
       COALESCE(f.ic_inferida, 0)        AS ic_inferida,
       COALESCE(f.dislipidemia_inferida, 0) AS dislipidemia_inferida,
       l.albumina_ultima, COALESCE(l.albumina_n, 0) AS albumina_n,
       l.albumina_pendiente, l.albumina_de,
       l.creatinina_ultima, COALESCE(l.creatinina_n, 0) AS creatinina_n,
       l.creatinina_pendiente,
       -- eGFR CKD-EPI 2021 sin raza
       CASE WHEN l.creatinina_ultima BETWEEN 0.2 AND 20 THEN
         142
         * POWER(LEAST(l.creatinina_ultima / CASE WHEN pe.sexo_masc = 1 THEN 0.9 ELSE 0.7 END, 1),
                 CASE WHEN pe.sexo_masc = 1 THEN -0.302 ELSE -0.241 END)
         * POWER(GREATEST(l.creatinina_ultima / CASE WHEN pe.sexo_masc = 1 THEN 0.9 ELSE 0.7 END, 1),
                 -1.200)
         * POWER(0.9938, pe.edad)
         * CASE WHEN pe.sexo_masc = 1 THEN 1 ELSE 1.012 END
       END AS egfr_ckdepi2021,
       l.urea_ultima, COALESCE(l.urea_n, 0) AS urea_n, l.urea_pendiente,
       l.pas_ultima, l.imc_ultimo,
       COALESCE(v.n_ambulatorias_365, 0) AS n_ambulatorias_365,
       COALESCE(v.n_hosp_365, 0)         AS n_hosp_365,
       COALESCE(v.n_urgencias_365, 0)    AS n_urgencias_365,
       e.estancia_indice_dias,
       -- Desenlace
       CASE WHEN c.death_date BETWEEN c.fecha_indice + INTERVAL 1 DAY
                                  AND c.fecha_indice + INTERVAL 90 DAY
            THEN 1 ELSE 0 END AS muerte_90d
FROM coh c
JOIN persona pe       ON pe.person_id = c.person_id
LEFT JOIN dx          ON dx.person_id = c.person_id
LEFT JOIN farmacos f  ON f.person_id  = c.person_id
LEFT JOIN labs l      ON l.person_id  = c.person_id
LEFT JOIN visitas v   ON v.person_id  = c.person_id
LEFT JOIN estancia e  ON e.person_id  = c.person_id
ORDER BY c.person_id
