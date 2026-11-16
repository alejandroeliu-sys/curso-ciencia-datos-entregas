import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(11, 3.5))

# Observación y predicción (días relativos al egreso)
ax.barh(0, 364, left=-365, height=0.5, color="#9ecae1", edgecolor="black")
ax.text(-183, 0, "Observación  [−365, −1]\nfármacos, laboratorios, visitas",
        ha="center", va="center", fontsize=9)
ax.barh(0, 90, left=0, height=0.5, color="#fc9272", edgecolor="black")
ax.text(47, 0, "Predicción\n[1, 90]\nmuerte", ha="center", va="center",
        fontsize=9)

# Blanqueo: el día 0
ax.barh(0, 8, left=-4, height=0.5, color="white", hatch="///",
        edgecolor="dimgray")
ax.annotate("Blanqueo: día 0\n(no a escala)", xy=(0, 0.27), xytext=(-120, 0.8),
            fontsize=8, arrowprops=dict(arrowstyle="->", color="dimgray"))

# Índice
ax.vlines(0, -0.35, 0.35, color="red", lw=2)
ax.text(0, -0.42, "Índice: día 0 (egreso)", color="red", ha="center",
        va="top", fontsize=9)

# Todo el historial previo
ax.annotate("", xy=(-470, 0.45), xytext=(-365, 0.45),
            arrowprops=dict(arrowstyle="->", color="navy", lw=1.5))
ax.text(-418, 0.55, "Crónicas: (−∞, −1]", color="navy", fontsize=8,
        ha="center")

ax.set_xlim(-480, 110)
ax.set_ylim(-0.9, 1.1)
ax.set_yticks([])
ax.set_xticks([-365, -180, -90, 0, 90])
ax.set_xlabel("Días relativos al egreso hospitalario")
ax.set_title("Anatomía temporal: muerte a 90 días tras el egreso (65+)")
for lado in ["left", "right", "top"]:
    ax.spines[lado].set_visible(False)

plt.tight_layout()
plt.savefig("figuras/linea_tiempo.png", dpi=450)
print("Guardado: figuras/linea_tiempo.png")
