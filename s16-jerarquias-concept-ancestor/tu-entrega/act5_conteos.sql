-- Actividad 5: tres formas de contar con dos ramas traslapadas
WITH registros AS (
    SELECT co.person_id, co.condition_concept_id, ca.ancestor_concept_id
    FROM condition_occurrence co
    JOIN concept_ancestor ca ON ca.descendant_concept_id = co.condition_concept_id
    WHERE ca.ancestor_concept_id IN (4182210, 378419)
)
SELECT count(*) AS a_filas_join,
       count(DISTINCT condition_concept_id) AS b_conceptos,
       count(DISTINCT person_id) AS c_pacientes
FROM registros;
