SELECT count(DISTINCT de.drug_concept_id) AS productos_sin_atc,
       count(*) AS registros_sin_atc
FROM drug_exposure de
WHERE de.drug_concept_id NOT IN (
    SELECT ca.descendant_concept_id
    FROM concept_ancestor ca
    JOIN concept a ON a.concept_id = ca.ancestor_concept_id
    WHERE a.vocabulary_id = 'ATC'
);
