# Actividad 10: traslape entre variantes del lavado y comprobación de anidamiento
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('tu-entrega/variantes_lavado.csv')
dias = [30, 180, 365, 730]
grupos = {d: set(df.loc[df['lavado_dias'] == d, 'subject_id']) for d in dias}

# Tabla de traslape: cuántos pacientes comparten cada par de variantes
tabla = pd.DataFrame(index=dias, columns=dias, dtype=int)
for a in dias:
    for b in dias:
        tabla.loc[a, b] = len(grupos[a] & grupos[b])
print('Pacientes en común (fila ∩ columna):')
print(tabla.to_string())

# Anidamiento: cada variante más estricta debe estar contenida en la anterior
for menor, mayor in zip(dias[:-1], dias[1:]):
    fuera = grupos[mayor] - grupos[menor]
    print(f'Lavado {mayor} dentro de {menor}: {"SÍ" if len(fuera) == 0 else "NO"} ({len(fuera)} fuera)')

# Figura: N por variante
plt.figure(figsize=(6, 4))
plt.bar([str(d) for d in dias], [len(grupos[d]) for d in dias], color='steelblue')
for i, d in enumerate(dias):
    plt.text(i, len(grupos[d]) + 1, str(len(grupos[d])), ha='center')
plt.xlabel('Lavado (días)')
plt.ylabel('Pacientes')
plt.title('Cohorte 1701: N según la duración del lavado')
plt.ylim(0, 220)
plt.tight_layout()
plt.savefig('tu-entrega/traslape_variantes.png', dpi=150)
print('Guardado tu-entrega/traslape_variantes.png')
