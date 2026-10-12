-- CONSULTA 4.1 Versión A estricta: solo la semilla Dementia
SELECT concept_id, concept_name, standard_concept
FROM concept
WHERE vocabulary_id = 'SNOMED'
  AND concept_code = '52448006';

-- CONSULTA 4.2 Versión B amplia: semilla y todos sus descendientes
SELECT c.concept_id, c.concept_name
FROM concept_ancestor ca
JOIN concept c ON c.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
)
ORDER BY c.concept_name;

-- CONSULTA 4.3 Versión C razonada: B menos las exclusiones
SELECT ca.descendant_concept_id AS concept_id
FROM concept_ancestor ca
WHERE ca.ancestor_concept_id = (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
)
EXCEPT
SELECT ca.descendant_concept_id
FROM concept_ancestor ca
WHERE ca.ancestor_concept_id IN (4182539,4019705,4047752,374341,37204554,37162253,37166530,42538609,37166361,37166338,
    (SELECT concept_id FROM concept WHERE vocabulary_id = 'SNOMED' AND concept_code = '230265002'));

-- CONSULTA 3.1 Mapeo CIE-10-CM de demencia a conceptos estándar (Maps to)
SELECT o.concept_code AS codigo_icd10,
       o.concept_id   AS concept_id_origen,
       e.concept_id   AS concept_id_estandar,
       e.concept_name AS nombre_estandar
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

-- CONSULTA 5.1 Pacientes distintos, versión A
SELECT count(DISTINCT person_id) AS pacientes
FROM condition_occurrence
WHERE condition_concept_id IN (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
);

-- CONSULTA 5.2 Pacientes distintos, versión B
SELECT count(DISTINCT person_id) AS pacientes
FROM condition_occurrence
WHERE condition_concept_id IN (
    SELECT ca.descendant_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id = (
        SELECT concept_id FROM concept
        WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
    )
);

-- CONSULTA 5.3 Pacientes distintos, versión C
SELECT count(DISTINCT person_id) AS pacientes
FROM condition_occurrence
WHERE condition_concept_id IN (
    SELECT ca.descendant_concept_id AS concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id = (
        SELECT concept_id FROM concept
        WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
    )
    EXCEPT
    SELECT ca.descendant_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id IN (4182539,4019705,4047752,374341,37204554,37162253,37166530,42538609,37166361,37166338,
        (SELECT concept_id FROM concept WHERE vocabulary_id = 'SNOMED' AND concept_code = '230265002'))
);

-- CONSULTA 6.1 Muestra de 20 descendientes para revisión manual
SELECT c.concept_id, c.concept_name, c.concept_class_id
FROM concept_ancestor ca
JOIN concept c ON c.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = (
    SELECT concept_id FROM concept
    WHERE vocabulary_id = 'SNOMED' AND concept_code = '52448006'
)
  AND ca.min_levels_of_separation > 0
ORDER BY hash(c.concept_id::VARCHAR || 'semilla42')
LIMIT 20;
