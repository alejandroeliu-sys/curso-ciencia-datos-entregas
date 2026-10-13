SELECT de.drug_concept_id, c.concept_name, c.concept_class_id, count(*) AS n
FROM drug_exposure de
JOIN concept c ON c.concept_id = de.drug_concept_id
GROUP BY de.drug_concept_id, c.concept_name, c.concept_class_id
ORDER BY n DESC
LIMIT 20;
