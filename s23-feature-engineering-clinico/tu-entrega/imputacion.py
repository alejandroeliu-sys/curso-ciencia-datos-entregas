# Actividad 9:
import pandas as pd
from sklearn.experimental import enable_iterative_imputer  # noqa: F401
from sklearn.impute import SimpleImputer, IterativeImputer
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import StratifiedKFold, cross_validate

df = pd.read_csv("features.csv")
y = df["muerte_90d"]
X = df.drop(columns=["person_id", "fecha_indice", "muerte_90d"], errors="ignore")
X = X.select_dtypes("number")
print("X:", X.shape, "| eventos:", int(y.sum()))

def modelo():
    return LogisticRegression(max_iter=2000, class_weight="balanced")

estrategias = {
    "A_mediana": Pipeline([
        ("imp", SimpleImputer(strategy="median")),
        ("esc", StandardScaler()),
        ("lr", modelo()),
    ]),
    "B_mediana_indicador": Pipeline([
        ("imp", SimpleImputer(strategy="median", add_indicator=True)),
        ("esc", StandardScaler()),
        ("lr", modelo()),
    ]),
    "C_iterativa": Pipeline([
        ("imp", IterativeImputer(max_iter=10, random_state=42)),
        ("esc", StandardScaler()),
        ("lr", modelo()),
    ]),
}

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
filas = []
for nombre, pipe in estrategias.items():
    r = cross_validate(pipe, X, y, cv=cv,
                       scoring={"auroc": "roc_auc", "auprc": "average_precision"})
    filas.append({
        "estrategia": nombre,
        "AUROC": f"{r['test_auroc'].mean():.3f} ± {r['test_auroc'].std():.3f}",
        "AUPRC": f"{r['test_auprc'].mean():.3f} ± {r['test_auprc'].std():.3f}",
    })
    print("listo:", nombre)

print(f"\nPrevalencia (AUPRC de un modelo al azar): {y.mean():.3f}")
print(pd.DataFrame(filas).to_string(index=False))
