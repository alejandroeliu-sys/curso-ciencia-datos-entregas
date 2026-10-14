# Actividad 3

**Conteos:** 724 tipos de relación; 124 jerárquicas; 63 definen ancestros; 55 cumplen ambas. Los conjuntos NO coinciden exactamente.

**Relaciones que salen de metformina (1503297):** 9 tipos distintos.

| Relación | n | Explicación |
|---|---|---|
| Mapped from | 120 | Códigos de otros vocabularios (no estándar) que se traducen a metformina. |
| RxNorm ing of | 75 | Metformina es ingrediente de esos 75 productos. Es la única jerárquica que define ancestros. |
| Has brand name | 23 | Nombres comerciales que contienen metformina (por ejemplo, Glucophage). |
| RxNorm - ATC pr lat | 23 | Liga metformina con su clase ATC (A10BA02, biguanidas). |
| RxNorm - SNOMED eq | 2 | Equivalente de metformina en SNOMED. |

**Conexión con la actividad 2:** CONCEPT_ANCESTOR solo se construye con relaciones que tienen defines_ancestry = 1 y entre conceptos estándar. Por eso la recursiva, que siguió todas las 'Is a', encontró 6 conceptos de clasificación no estándar que CONCEPT_ANCESTOR omitio.
