SELECT c.concept_id, c.concept_code, c.concept_name,
       count(*) AS mediciones
FROM measurement m
JOIN concept c ON c.concept_id = m.measurement_concept_id
WHERE c.vocabulary_id = 'LOINC'
  AND (c.concept_name ILIKE '%A1c%' OR c.concept_name ILIKE '%glycated%')
GROUP BY c.concept_id, c.concept_code, c.concept_name
ORDER BY mediciones DESC;
