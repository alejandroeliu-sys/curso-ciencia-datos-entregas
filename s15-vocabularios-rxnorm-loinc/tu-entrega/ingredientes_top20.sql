WITH top20 AS (
    SELECT drug_concept_id, count(*) AS n
    FROM drug_exposure
    GROUP BY drug_concept_id
    ORDER BY n DESC
    LIMIT 20
)
SELECT t.drug_concept_id, p.concept_name, p.concept_class_id,
       i.concept_name AS ingrediente
FROM top20 t
JOIN concept p ON p.concept_id = t.drug_concept_id
JOIN concept_ancestor ca ON ca.descendant_concept_id = t.drug_concept_id
JOIN concept i ON i.concept_id = ca.ancestor_concept_id
WHERE i.concept_class_id = 'Ingredient'
ORDER BY t.n DESC;
