# Laboratorio 10 — Base clínica

## Datos

Los CSV se generan con Synthea. Comando:

```bash
java -jar synthea-with-dependencies.jar -s 42 -p 5000 --exporter.csv.export=true --exporter.fhir.export=false --exporter.csv.included_files=patients.csv,encounters.csv,conditions.csv,medications.csv,observations.csv --exporter.csv.excluded_files= Massachusetts
```

## Motor

Trabajo solo en mi computadora, así que no necesito un servidor al que se conecten otras personas. DuckDB guarda la base en un archivo, corre SQL y el script de carga se puede repetir. PostgreSQL se parecería más a OHDSI, pero esa semejanza no aporta mientras los datos viven en CSV y solo los consulta una persona.

## Diagrama

El dibujo completo está en [diagrama.md](diagrama.md). Lo repito aquí para verlo en esta misma página.

```mermaid
erDiagram
    patients ||--o{ encounters : "Id = PATIENT"
    patients ||--o{ conditions : "Id = PATIENT"
    patients ||--o{ medications : "Id = PATIENT"
    patients ||--o{ observations : "Id = PATIENT"
    encounters ||--o{ conditions : "Id = ENCOUNTER"
    encounters ||--o{ medications : "Id = ENCOUNTER"
    encounters ||--o{ observations : "Id = ENCOUNTER"

    patients {
        string Id PK
        date BIRTHDATE
        date DEATHDATE
        string GENDER
    }
    encounters {
        string Id PK
        timestamp START
        timestamp STOP
        string PATIENT FK
        string ENCOUNTERCLASS
    }
    conditions {
        date START
        date STOP
        string PATIENT FK
        string ENCOUNTER FK
        string CODE
        string DESCRIPTION
    }
    medications {
        timestamp START
        timestamp STOP
        string PATIENT FK
        string ENCOUNTER FK
        string DESCRIPTION
    }
    observations {
        timestamp DATE
        string PATIENT FK
        string ENCOUNTER FK
        string CODE
        string VALUE
    }
```
