# Algoritmo de estimación

## 1. Control físico de cada espécimen

La aplicación recalcula los dos parámetros derivados directamente de las masas:

- Absorción: `A = 100 × (Msat − Mseca) / Mseca`
- Densidad: `ρ = 1000 × Mseca / (Msat − Minmersa)`

Un registro solo entra al cálculo cuando cumple, entre otros controles:

- `Msat ≥ Mseca > 0`
- `0 ≤ Minmersa < Msat`
- `0 % ≤ A ≤ 30 %`
- `1200 kg/m³ ≤ ρ ≤ 3000 kg/m³`
- En flexotracción: `10 mm ≤ espesor ≤ 300 mm`

La fila puede conservarse en la base aunque quede marcada como no válida para predicción.

## 2. Limpieza estadística

Dentro de cada modelo se aplica un filtro robusto por desviación absoluta mediana (MAD):

- Compresión: masa seca y densidad.
- Flexotracción: masa seca por milímetro de espesor y densidad.

El filtro MAD evita que errores aislados alteren la estimación sin depender de una distribución normal.

## 3. Condicionamiento por absorción

Cada espécimen recibe un peso gaussiano según su distancia respecto a la absorción solicitada. Los datos más cercanos pesan más, pero se conserva un peso mínimo para no ignorar por completo el resto del histórico.

En vez de un promedio único se seleccionan representantes ponderados en:

- P15: escenario bajo.
- P50: escenario típico.
- P85: escenario alto.

## 4. Compresión

La masa seca procede del espécimen representativo de cada percentil. Luego se calculan:

- `Msat = Mseca × (1 + Aobjetivo / 100)`
- `Minmersa = Msat − Mseca × 1000 / ρ`
- `Mnatural = Mseca × (1 + humedad_histórica / 100)`

La humedad histórica se toma del mismo espécimen cuando es válida; de lo contrario se usa la mediana ponderada del modelo. La masa natural siempre se limita físicamente entre la masa seca y la saturada.

## 5. Flexotracción

Para respetar el espesor, la variable estadística es:

`masa específica lineal = Mseca / espesor`

Para el espesor solicitado:

`Mseca_objetivo = (Mseca_histórica / espesor_histórico) × espesor_objetivo`

Después se calculan masa saturada e inmersa con las ecuaciones anteriores. Así, un adoquín de 82 mm no reutiliza directamente una masa perteneciente a un espécimen de 60 mm.

## 6. Extrapolaciones

La aplicación avisa cuando la absorción o el espesor están fuera del rango histórico del modelo. El cálculo se permite, pero la confianza baja y el resultado debe validarse con criterio técnico.
