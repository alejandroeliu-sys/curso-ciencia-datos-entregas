import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

versiones = ["A monoterapia", "B todo el ingrediente", "C B sin iSGLT2"]
pacientes = [228, 228, 228]

plt.figure(figsize=(7, 4))
barras = plt.bar(versiones, pacientes, color=["#bbbbbb", "#4a7ebb", "#2e8b57"])
for b, n in zip(barras, pacientes):
    plt.text(b.get_x() + b.get_width() / 2, n + 3, str(n), ha="center")
plt.ylabel("Pacientes distintos")
plt.title("Exposición a metformina: con las tres definiciones A, B y C	")
plt.tight_layout()
plt.savefig("tu-entrega/impacto_metformina.png", dpi=600)
print("Gráfica guardada")
