import duckdb
import matplotlib.pyplot as plt
import os

con = duckdb.connect(os.path.expanduser('~/s12-omop-cdm-introduccion/omop.duckdb'), read_only=True)
valores = con.sql("""
    SELECT value_as_number
    FROM measurement
    WHERE measurement_concept_id = 3004410
      AND value_as_number IS NOT NULL
""").df()

plt.hist(valores['value_as_number'], bins=40)
plt.axvline(6.5, color='red', linestyle='--', label='Umbral diabetes (6.5 %)')
plt.xlabel('HbA1c (%)')
plt.ylabel('Número de mediciones')
plt.title('Distribución de HbA1c (LOINC 4548-4)')
plt.legend()
plt.tight_layout()
plt.savefig('tu-entrega/histograma_hba1c.png', dpi=300)
print("Histograma guardado")
