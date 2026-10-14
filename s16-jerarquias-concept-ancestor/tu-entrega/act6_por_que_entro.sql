-- Actividad 6: ¿por qué entró este paciente a la cohorte de demencia?
-- Para otro paciente, cambia solo el número en "parametros".
WITH parametros AS (
    SELECT 371 AS pid
)
SELECT co.person_id,
       co.condition_occurrence_id AS evento,
       co.condition_start_date AS fecha,
       co.condition_source_value AS codigo_fuente,
       co.condition_source_concept_id AS source_concept_id,
       src.concept_name AS concepto_fuente,
       co.condition_concept_id AS concepto_estandar_id,
       std.concept_name AS concepto_estandar,
       ca.ancestor_concept_id AS ancestro_del_set,
       anc.concept_name AS rama,
       ca.min_levels_of_separation AS niveles
FROM condition_occurrence co
JOIN parametros p ON co.person_id = p.pid
LEFT JOIN concept src ON src.concept_id = co.condition_source_concept_id
JOIN concept std ON std.concept_id = co.condition_concept_id
JOIN concept_ancestor ca ON ca.descendant_concept_id = co.condition_concept_id
JOIN concept anc ON anc.concept_id = ca.ancestor_concept_id
WHERE ca.ancestor_concept_id IN (4182210, 378419)
ORDER BY fecha;
