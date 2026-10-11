# Laboratorio s10 — Resultados

Datos: Synthea, semilla 42, Massachusetts, al menos 5 000 pacientes.
Carpeta: `s10-sql-fundamentals`.

## Actividad 1. Generar los datos

Comando:

```bash
java -jar synthea-with-dependencies.jar -s 42 -p 5000 --exporter.csv.export=true --exporter.fhir.export=false --exporter.csv.included_files=patients.csv,encounters.csv,conditions.csv,medications.csv,observations.csv --exporter.csv.excluded_files= Massachusetts
```

Synthea generó 5 706 pacientes. Se crearon `patients.csv`, `encounters.csv`, `conditions.csv`, `medications.csv` y `observations.csv`.

## Actividad 2. Motor

Se eligio a DuckDB..

DuckDB guarda la base en un archivo, corre SQL y el script de carga se puede repetir. En PostgreSQL solo los consulta una persona.

## Actividad 3. Carga

Conteos:

- patients: 5 706
- encounters: 324 239
- conditions: 202 868
- medications: 271 611
- observations: 4 130 541

## Actividad 4. Diagrama utilizando mermaid.live

- `patients`: llave primaria `Id`. No apunta a otra tabla.
- `encounters`: primaria `Id`. Foránea `PATIENT` hacia `patients.Id`. `ORGANIZATION`, `PROVIDER` y `PAYER` apuntan a tablas que no se cargaron.
- `conditions`, `medications` y `observations` no traen `Id`. Son eventos. Sus foráneas son `PATIENT` hacia `patients.Id` y `ENCOUNTER` hacia `encounters.Id`.

Un paciente tiene muchas visitas. Cada visita puede tener varios diagnósticos, medicamentos y mediciones. La grafica está en `diagrama.md`.

## Actividad 5. Auditoría

- Ids duplicados en `patients`: 0.
- Encuentros anteriores al nacimiento: 0.
- `VALUE` nulo en observations: 0 de 4 130 541, es decir 0 por ciento.
- Encuentros cuyo paciente no existe: 0. Esta es el anti-join.

## Actividad 6. Quince preguntas

1. Hay 5 706 pacientes y 5 000 siguen vivos (`DEATHDATE` nula).
2. Por sexo: 2 920 mujeres y 2 786 hombres.
3. Los 10 diagnósticos más frecuentes:
   - Medication review due (situation): 39 923
   - Stress (finding): 15 561
   - Gingivitis (disorder): 14 933
   - Full-time employment (finding): 14 454
   - Part-time employment (finding): 9 078
   - Viral sinusitis (disorder): 5 832
   - Limited social contact (finding): 5 685
   - Social isolation (finding): 5 505
   - Not in labor force (finding): 4 490
   - Gingival disease (disorder): 4 447
4. Nacidos antes de 1960: PEGAR AQUÍ la salida de la pregunta 4.
5. Encuentros por año: PEGAR AQUÍ la salida de la pregunta 5.
6. Media y mediana de encuentros por paciente: PEGAR AQUÍ la salida de la pregunta 6.
7. Edad media al primer diagnóstico de diabetes mellitus: PEGAR AQUÍ la salida de la pregunta 7.
8. Diagnósticos con más de 50 pacientes distintos: PEGAR AQUÍ la salida de la pregunta 8.
9. Hemoglobina glucosilada, 42 422 mediciones. Media 4.7, mediana 4.6, percentil 10 igual a 2.9, percentil 90 igual a 6.3.
10. Pacientes por grupo de edad y sexo (0-17, 18-39, 40-64, 65 o más). La consulta sí corrió. PEGAR AQUÍ la tabla, porque en la captura los conteos no se leen con seguridad.
11. Pacientes con diabetes y hipertensión: 631.
12. Anti-join. Pacientes con diabetes sin ninguna hemoglobina glucosilada: 128.
13. Para cada paciente, el primer y el último encuentro. Se mostraron 10. En todos, la primera fecha es anterior o igual a la última.
14. El medicamento más frecuente entre quienes tienen diabetes es sodium fluoride 0.0272 MG/MG Oral Gel, en 785 pacientes. No es un fármaco de la diabetes. La pregunta pide el más común entre esas personas, y el flúor dental se da a casi todo el mundo en estos datos.
15. Anti-join. Encuentros de urgencias sin diagnóstico en esa visita: 4 131.

## Actividad 7. El join que multiplica

Promedio correcto: 5.66 horas.
Promedio inflado: 2.49 horas.
Promedio corregido: 5.66 horas.

Filas antes del join: 324 239. Filas después: 202 868.

## Actividad 8. La trampa del LEFT JOIN

Filtro en el WHERE: 12 301 filas y 3 999 pacientes.
Filtro en el ON: 14 018 filas y 5 706 pacientes.

Si la persona no tiene una urgencia, las columnas del encuentro quedan nulas. En el WHERE esa comparación no se cumple y la persona desaparece, así que el LEFT JOIN se comporta como inner join. En el ON el filtro solo elige qué encuentro se pega y la persona sin urgencias se conserva. Por eso reaparece el total de pacientes. Hay más filas que personas porque varios tuvieron más de una urgencia.

## Actividad 9. Rendimiento

Consulta medida: distribución de hemoglobina glucosilada.

Sin índice: 0.016 segundos.
Con índice en `DESCRIPTION`: 0.01 segundos.
## Actividad 10

Tres consultas, ya con los datos en memoria:

- Pacientes y vivos: 0.001 segundos. 5 706 pacientes, 5 000 vivos.
- Sexo: 0.001 segundos. 2 920 mujeres, 2 786 hombres.
- Diez diagnósticos: 0.015 segundos.


