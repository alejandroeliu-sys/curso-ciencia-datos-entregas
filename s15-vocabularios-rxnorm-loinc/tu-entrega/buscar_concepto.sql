-- Actividad 8: conceptos estándar para el catálogo local (15 términos)
SELECT concept_id, concept_code, concept_name, vocabulary_id, domain_id, standard_concept
FROM concept
WHERE (vocabulary_id = 'LOINC' AND concept_code IN
        ('2160-0','33863-2','4548-4','2345-7','718-7','1751-7','2823-3','2951-2','3094-0'))
   OR (vocabulary_id = 'RxNorm' AND concept_code IN
        ('6809','2418','3264','4603','3827','7646'))
ORDER BY vocabulary_id, concept_code;
