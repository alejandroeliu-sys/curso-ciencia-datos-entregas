# Laboratorio 12 — Diagrama ER de las tablas cargadas en `omop.duckdb`

Tablas creadas por `sql/cargar_vocab.py` (vocabulario) y `sql/convertir.py`
(datos clínicos), con las columnas de la DDL oficial OMOP CDM v5.4.

- **PK** = clave primaria (en DuckDB solo declaramos las PK de las tablas clínicas).
- **FK** = clave foránea *lógica* (la DDL oficial las crea en un script aparte;
  aquí **no** se imponen como restricción, solo se documentan).
- Todas las columnas `*_concept_id` son FK a `CONCEPT.concept_id`. Para no
  saturar el dibujo, solo se dibujan algunas de esas líneas.
- `DRUG_EXPOSURE` y `MEASUREMENT` son opcionales (se muestran solo sus columnas principales).

```mermaid
erDiagram
    PERSON ||--o{ OBSERVATION_PERIOD : "person_id"
    PERSON ||--o{ VISIT_OCCURRENCE : "person_id"
    PERSON ||--o{ CONDITION_OCCURRENCE : "person_id"
    PERSON ||--o{ DRUG_EXPOSURE : "person_id"
    PERSON ||--o{ MEASUREMENT : "person_id"
    VISIT_OCCURRENCE |o--o{ CONDITION_OCCURRENCE : "visit_occurrence_id"
    VISIT_OCCURRENCE |o--o{ DRUG_EXPOSURE : "visit_occurrence_id"
    VISIT_OCCURRENCE |o--o{ MEASUREMENT : "visit_occurrence_id"
    VISIT_OCCURRENCE |o--o{ VISIT_OCCURRENCE : "preceding_visit_occurrence_id"

    CONCEPT ||--o{ PERSON : "gender / race / ethnicity_concept_id"
    CONCEPT ||--o{ OBSERVATION_PERIOD : "period_type_concept_id"
    CONCEPT ||--o{ VISIT_OCCURRENCE : "visit_concept_id / visit_type_concept_id"
    CONCEPT ||--o{ CONDITION_OCCURRENCE : "condition_concept_id / condition_source_concept_id"
    CONCEPT ||--o{ DRUG_EXPOSURE : "drug_concept_id"
    CONCEPT ||--o{ MEASUREMENT : "measurement_concept_id / unit_concept_id"
    CONCEPT ||--o{ CONCEPT_RELATIONSHIP : "concept_id_1 / concept_id_2"
    CONCEPT ||--o{ CONCEPT_ANCESTOR : "ancestor / descendant_concept_id"
    VOCABULARY ||--o{ CONCEPT : "vocabulary_id"
    DOMAIN ||--o{ CONCEPT : "domain_id"

    PERSON {
        integer person_id PK
        integer gender_concept_id FK
        integer year_of_birth
        integer month_of_birth
        integer day_of_birth
        timestamp birth_datetime
        integer race_concept_id FK
        integer ethnicity_concept_id FK
        integer location_id FK "NULL en este ETL"
        integer provider_id FK "NULL en este ETL"
        integer care_site_id FK "NULL en este ETL"
        varchar person_source_value "Id de Synthea"
        varchar gender_source_value
        integer gender_source_concept_id FK
        varchar race_source_value
        integer race_source_concept_id FK
        varchar ethnicity_source_value
        integer ethnicity_source_concept_id FK
    }

    OBSERVATION_PERIOD {
        integer observation_period_id PK
        integer person_id FK
        date observation_period_start_date
        date observation_period_end_date
        integer period_type_concept_id FK "32817 EHR"
    }

    VISIT_OCCURRENCE {
        integer visit_occurrence_id PK
        integer person_id FK
        integer visit_concept_id FK
        date visit_start_date
        timestamp visit_start_datetime
        date visit_end_date
        timestamp visit_end_datetime
        integer visit_type_concept_id FK "32817 EHR"
        integer provider_id FK "NULL"
        integer care_site_id FK "NULL"
        varchar visit_source_value "ENCOUNTERCLASS"
        integer visit_source_concept_id FK
        integer admitted_from_concept_id FK "NULL"
        varchar admitted_from_source_value
        integer discharged_to_concept_id FK "NULL"
        varchar discharged_to_source_value
        integer preceding_visit_occurrence_id FK
    }

    CONDITION_OCCURRENCE {
        integer condition_occurrence_id PK
        integer person_id FK
        integer condition_concept_id FK "via Maps to"
        date condition_start_date
        timestamp condition_start_datetime
        date condition_end_date
        timestamp condition_end_datetime
        integer condition_type_concept_id FK "32817 EHR"
        integer condition_status_concept_id FK "NULL"
        varchar stop_reason
        integer provider_id FK "NULL"
        integer visit_occurrence_id FK
        integer visit_detail_id FK "NULL, sin VISIT_DETAIL"
        varchar condition_source_value "CODE SNOMED de Synthea"
        integer condition_source_concept_id FK
        varchar condition_status_source_value
    }

    DRUG_EXPOSURE {
        integer drug_exposure_id PK
        integer person_id FK
        integer drug_concept_id FK
        date drug_exposure_start_date
        date drug_exposure_end_date
        integer drug_type_concept_id FK
        integer visit_occurrence_id FK
        varchar drug_source_value "CODE RxNorm"
        integer drug_source_concept_id FK
    }

    MEASUREMENT {
        integer measurement_id PK
        integer person_id FK
        integer measurement_concept_id FK
        date measurement_date
        integer measurement_type_concept_id FK
        numeric value_as_number
        integer unit_concept_id FK
        integer visit_occurrence_id FK
        varchar measurement_source_value "CODE LOINC"
        integer measurement_source_concept_id FK
        varchar unit_source_value
    }

    CONCEPT {
        integer concept_id PK
        varchar concept_name
        varchar domain_id FK
        varchar vocabulary_id FK
        varchar concept_class_id
        varchar standard_concept "S, C o NULL"
        varchar concept_code
        date valid_start_date
        date valid_end_date
        varchar invalid_reason
    }

    CONCEPT_RELATIONSHIP {
        integer concept_id_1 FK
        integer concept_id_2 FK
        varchar relationship_id "p. ej. Maps to"
        date valid_start_date
        date valid_end_date
        varchar invalid_reason
    }

    CONCEPT_ANCESTOR {
        integer ancestor_concept_id FK
        integer descendant_concept_id FK
        integer min_levels_of_separation
        integer max_levels_of_separation
    }

    VOCABULARY {
        varchar vocabulary_id PK
        varchar vocabulary_name
        varchar vocabulary_reference
        varchar vocabulary_version
        integer vocabulary_concept_id FK
    }

    DOMAIN {
        varchar domain_id PK
        varchar domain_name
        integer domain_concept_id FK
    }
```

## Diferencias entre nuestro ETL "a mano" y la especificación oficial v5.4

Las **columnas y tipos** de las tablas son los de la DDL oficial v5.4 (lo
comprobamos columna a columna). Lo que cambia es **cómo se rellenan** y
**qué tablas faltan**:

| # | Diferencia | ¿Simplificación legítima? |
|---|------------|---------------------------|
| 1 | **`provider_id`, `care_site_id` y `location_id` quedan en NULL** y no existen las tablas `PROVIDER`, `CARE_SITE` ni `LOCATION` (Synthea sí tiene esa información en `providers.csv` / `organizations.csv`, pero no los exportamos). | **Sí.** En v5.4 esas columnas admiten NULL. Se pierde información (no podríamos analizar por proveedor u hospital), pero el modelo sigue siendo válido. |
| 2 | **`observation_period` se deduce de los encuentros**: un único periodo por persona, de la primera a la última visita. No hay datos de afiliación/seguro. | **Sí, es práctica habitual en datos EHR** (el ETL oficial ETL-Synthea hace lo mismo). Pero tiene efectos: por zona horaria (Synthea escribe la fecha de la condición en hora local y la del encuentro en UTC), algunas condiciones quedan 1 día *antes* del inicio del periodo (actividad 8). |
| 3 | **No hay enrutado por dominio**: todo `conditions.csv` va a `condition_occurrence`, aunque el concepto estándar sea del dominio *Observation* (empleo, estrés, educación... ver consulta 5.3). | **No del todo.** Las convenciones OMOP dicen que cada registro va a la tabla de su dominio (estos deberían ir a `OBSERVATION`). Aceptable para un primer lab, pero hay que saberlo. |
| 4 | **Sin `VISIT_DETAIL`** y 1 encuentro = 1 visita (el ETL oficial fusiona encuentros hospitalarios consecutivos y descarta las clases virtual/home/hospice/snf; nosotros las dejamos con `visit_concept_id = 0`). | **Sí.** `VISIT_DETAIL` es opcional; las visitas sin mapeo con 0 cumplen la convención. |
| 5 | **Un solo Type Concept (32817 EHR)** para visitas, condiciones y periodos (el ETL oficial usa conceptos más específicos). | **Sí.** 32817 es un concepto estándar válido del vocabulario *Type Concept*. |
| 6 | Faltan otras tablas: `DEATH` (aunque Synthea tiene `DEATHDATE`), `CDM_SOURCE`, `OBSERVATION`, `PROCEDURE_OCCURRENCE`, las tablas *era* (`CONDITION_ERA`, `DRUG_ERA`). Tampoco hay restricciones FK en DuckDB. | **Sí para el lab**, pero herramientas como Achilles o Data Quality Dashboard esperan `CDM_SOURCE` y las tablas *era*. |
