import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

versiones = ["A estricta\n(1 concepto)", "B amplia\n(216 conceptos)", "C razonada\n(190 conceptos)"]
pacientes = [0, 147, 116]

plt.figure(figsize=(7, 4))
barras = plt.bar(versiones, pacientes, color=["#bbbbbb", "#4a7ebb", "#2e8b57"])
for b, n in zip(barras, pacientes):
    plt.text(b.get_x() + b.get_width() / 2, n + 2, str(n), ha="center")
plt.ylabel("Pacientes distintos")
plt.title("Impacto de la definición usada de demencia en la cohorte")
plt.tight_layout()
plt.savefig("tu-entrega/impacto_pacientes.png", dpi=600)
print("Gráfica guardada")
