from pathlib import Path
import duckdb

base = Path.home() / "s10-sql-fundamentals"
con = duckdb.connect(str(base / "clinica.duckdb"))


def mostrar(titulo, sql):
    print("\n" + titulo)
    cur = con.execute(sql)
    nombres = [c[0] for c in cur.description]
    filas = cur.fetchall()
    print(" | ".join(nombres))
    if not filas:
        print("(ninguna fila)")
        return
    for fila in filas:
        print(" | ".join(str(valor) for valor in fila))


# 1. Cuántos pacientes hay y cuántos siguen vivos.
# Vivo = DEATHDATE nula.
mostrar(
    "1. Pacientes y vivos",
    """
    SELECT
        COUNT(*) AS pacientes,
        COUNT(*) FILTER (WHERE DEATHDATE IS NULL) AS vivos
    FROM patients
    """,
)

# 2. Distribución por sexo.
mostrar(
    "2. Pacientes por sexo",
    """
    SELECT GENDER AS sexo, COUNT(*) AS pacientes
    FROM patients
    GROUP BY GENDER
    ORDER BY pacientes DESC
    """,
)

# 3. Los 10 diagnósticos más frecuentes.
mostrar(
    "3. Diez diagnósticos más frecuentes",
    """
    SELECT DESCRIPTION AS diagnostico, COUNT(*) AS casos
    FROM conditions
    GROUP BY DESCRIPTION
    ORDER BY casos DESC
    LIMIT 10
    """,
)

# 4. Pacientes nacidos antes de 1960.
mostrar(
    "4. Nacidos antes de 1960",
    """
    SELECT COUNT(*) AS nacidos_antes_de_1960
    FROM patients
    WHERE BIRTHDATE < DATE '1960-01-01'
    """,
)

# 5. Encuentros por año.
mostrar(
    "5. Encuentros por año",
    """
    SELECT
        EXTRACT(YEAR FROM START) AS anio,
        COUNT(*) AS encuentros
    FROM encounters
    GROUP BY EXTRACT(YEAR FROM START)
    ORDER BY anio
    """,
)

# 6. Media y mediana de encuentros por paciente.
# Solo entran pacientes que tuvieron al menos un encuentro.
mostrar(
    "6. Media y mediana de encuentros por paciente",
    """
    SELECT
        ROUND(AVG(n), 2) AS media,
        MEDIAN(n) AS mediana
    FROM (
        SELECT COUNT(*) AS n
        FROM encounters
        GROUP BY PATIENT
    ) AS por_paciente
    """,
)

# 7. Edad media al primer diagnóstico de diabetes mellitus.
mostrar(
    "7. Edad media al primer diagnóstico de diabetes mellitus",
    """
    WITH primera AS (
        SELECT PATIENT, MIN(START) AS fecha
        FROM conditions
        WHERE DESCRIPTION ILIKE '%diabetes mellitus%'
        GROUP BY PATIENT
    )
    SELECT
        COUNT(*) AS pacientes,
        ROUND(AVG(DATE_DIFF('year', p.BIRTHDATE, primera.fecha)), 1) AS edad_media
    FROM primera
    JOIN patients AS p
        ON p.Id = primera.PATIENT
    """,
)

# 8. Diagnósticos con más de 50 pacientes distintos.
mostrar(
    "8. Diagnósticos con más de 50 pacientes",
    """
    SELECT
        DESCRIPTION AS diagnostico,
        COUNT(DISTINCT PATIENT) AS pacientes
    FROM conditions
    GROUP BY DESCRIPTION
    HAVING COUNT(DISTINCT PATIENT) > 50
    ORDER BY pacientes DESC
    """,
)

# 9. Distribución de HbA1c: media, mediana, p10 y p90.
# VALUE se cargó como texto, así que se convierte a número.
mostrar(
    "9. Distribución de HbA1c",
    """
    SELECT
        COUNT(*) AS n,
        ROUND(AVG(valor), 2) AS media,
        ROUND(MEDIAN(valor), 2) AS mediana,
        ROUND(QUANTILE_CONT(valor, 0.1), 2) AS p10,
        ROUND(QUANTILE_CONT(valor, 0.9), 2) AS p90
    FROM (
        SELECT TRY_CAST(VALUE AS DOUBLE) AS valor
        FROM observations
        WHERE DESCRIPTION ILIKE '%Hemoglobin A1c%'
          AND "TYPE" = 'numeric'
    ) AS mediciones
    WHERE valor IS NOT NULL
    """,
)

# 10. Pacientes por grupo de edad y sexo.
# Edad al morir, o a hoy si sigue vivo.
mostrar(
    "10. Pacientes por grupo de edad y sexo",
    """
    WITH edades AS (
        SELECT
            GENDER AS sexo,
            DATE_DIFF(
                'year',
                BIRTHDATE,
                COALESCE(DEATHDATE, CURRENT_DATE)
            ) AS edad
        FROM patients
    )
    SELECT
        CASE
            WHEN edad < 18 THEN '0-17'
            WHEN edad < 40 THEN '18-39'
            WHEN edad < 65 THEN '40-64'
            ELSE '65 o más'
        END AS grupo,
        sexo,
        COUNT(*) AS pacientes
    FROM edades
    GROUP BY grupo, sexo
    ORDER BY grupo, sexo
    """,
)

# 11. Pacientes con diabetes y hipertensión.
mostrar(
    "11. Pacientes con diabetes y hipertensión",
    """
    SELECT COUNT(*) AS pacientes
    FROM (
        SELECT DISTINCT PATIENT
        FROM conditions
        WHERE DESCRIPTION ILIKE '%diabetes mellitus%'
    ) AS diabetes
    JOIN (
        SELECT DISTINCT PATIENT
        FROM conditions
        WHERE DESCRIPTION ILIKE '%Hypertension%'
    ) AS hipertension
        ON diabetes.PATIENT = hipertension.PATIENT
    """,
)

# 12. Anti-join: diabetes sin ninguna HbA1c.
mostrar(
    "12. Diabetes sin medición de HbA1c",
    """
    SELECT COUNT(*) AS pacientes
    FROM (
        SELECT DISTINCT PATIENT
        FROM conditions
        WHERE DESCRIPTION ILIKE '%diabetes mellitus%'
    ) AS diabetes
    LEFT JOIN (
        SELECT DISTINCT PATIENT
        FROM observations
        WHERE DESCRIPTION ILIKE '%Hemoglobin A1c%'
    ) AS hba1c
        ON diabetes.PATIENT = hba1c.PATIENT
    WHERE hba1c.PATIENT IS NULL
    """,
)

# 13. Primer y último encuentro de cada paciente.
# Aquí solo se muestran 10 para no llenar la terminal.
mostrar(
    "13. Primer y último encuentro (10 pacientes)",
    """
    SELECT
        PATIENT,
        MIN(START) AS primer_encuentro,
        MAX(START) AS ultimo_encuentro
    FROM encounters
    GROUP BY PATIENT
    ORDER BY PATIENT
    LIMIT 10
    """,
)

# 14. Medicamento más frecuente entre pacientes con diabetes.
# COUNT DISTINCT para no contar varias veces al mismo paciente.
mostrar(
    "14. Medicamento más frecuente en diabetes",
    """
    SELECT
        m.DESCRIPTION AS medicamento,
        COUNT(DISTINCT m.PATIENT) AS pacientes
    FROM medications AS m
    JOIN conditions AS c
        ON m.PATIENT = c.PATIENT
    WHERE c.DESCRIPTION ILIKE '%diabetes mellitus%'
    GROUP BY m.DESCRIPTION
    ORDER BY pacientes DESC
    LIMIT 1
    """,
)

# 15. Anti-join: urgencias sin diagnóstico en ese encuentro.
mostrar(
    "15. Urgencias sin diagnóstico",
    """
    SELECT COUNT(*) AS encuentros
    FROM encounters AS e
    LEFT JOIN conditions AS c
        ON e.Id = c.ENCOUNTER
    WHERE e.ENCOUNTERCLASS = 'emergency'
      AND c.ENCOUNTER IS NULL
    """,
)

con.close()
