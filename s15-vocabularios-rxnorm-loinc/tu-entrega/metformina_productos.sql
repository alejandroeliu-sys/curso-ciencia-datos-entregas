SELECT p.concept_id, p.concept_name, p.concept_class_id,
       count(DISTINCT ing.concept_id) AS n_ingredientes,
       count(DISTINCT de.person_id) AS pacientes
FROM drug_exposure de
JOIN concept p ON p.concept_id = de.drug_concept_id
JOIN concept_ancestor ca ON ca.descendant_concept_id = p.concept_id
JOIN concept ing ON ing.concept_id = ca.ancestor_concept_id
WHERE ing.concept_class_id = 'Ingredient'
  AND p.concept_id IN (
      SELECT descendant_concept_id FROM concept_ancestor
      WHERE ancestor_concept_id = (SELECT concept_id FROM concept
          WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Ingredient' AND concept_code = '6809')
  )
GROUP BY p.concept_id, p.concept_name, p.concept_class_id;
