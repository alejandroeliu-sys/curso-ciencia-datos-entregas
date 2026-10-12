SELECT o.concept_code   AS codigo_icd10,
       o.concept_id     AS concept_id_origen,
       e.concept_id     AS concept_id_estandar,
       e.concept_name   AS nombre_estandar
FROM concept o
JOIN concept_relationship cr ON cr.concept_id_1 = o.concept_id
JOIN concept e ON e.concept_id = cr.concept_id_2
WHERE o.vocabulary_id = 'ICD10CM'
  AND o.concept_code IN ('F01.50','F01.511','F02.80','F02.811','F03.90','F03.911',
                         'G30.0','G30.1','G30.8','G30.9','G31.01','G31.83','F10.27')
  AND cr.relationship_id = 'Maps to'
  AND e.standard_concept = 'S'
  AND e.invalid_reason IS NULL
  AND cr.invalid_reason IS NULL
ORDER BY o.concept_code;
