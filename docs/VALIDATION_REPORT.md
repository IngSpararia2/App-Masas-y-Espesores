# Validación con los históricos suministrados

Archivos revisados:

- `Resumen_Compresion.xlsx`
- `Resumen_Flexotraccion.xlsx`

## Estructura detectada

| Histórico | Filas de datos | Especímenes con datos de masa | Especímenes físicamente válidos |
|---|---:|---:|---:|
| Compresión | 2.908 | 8.604 | 8.588 |
| Flexotracción | 1.020 | 5.072 | 5.057 |
| **Total** | **3.928** | **13.676** | **13.645** |

La validez se comprobó recalculando absorción y densidad y aplicando los rangos físicos documentados en `ALGORITHM.md`.


## Resultado esperado después de deduplicar

El histórico contiene algunas filas repetidas con la misma identidad y las mismas masas. La primera importación las consolida automáticamente. Con los dos archivos suministrados, la base local queda aproximadamente en:

- **13.644 registros únicos** almacenados.
- **13.615 registros únicos válidos** para predicción.
- 21 repeticiones internas detectadas en compresión y 9 en flexotracción.
- 2 especímenes de flexotracción rechazados por no contener el conjunto mínimo de masas.

## Hallazgo de columnas

En el resumen de flexotracción, valores del orden de `6–8` aparecen bajo el encabezado `Densidad`, mientras que valores del orden de `2.000 kg/m³` aparecen bajo `Absorcion`. Las magnitudes muestran que las dos columnas están intercambiadas.

La aplicación resuelve esto de forma segura:

1. Lee las tres masas.
2. Calcula absorción y densidad con sus ecuaciones físicas.
3. Usa los valores calculados para la base y la predicción.
4. Registra una observación de calidad cuando detecta la inversión.

## Normalización de modelos

El modelo de ejemplo indicado como `M12L-DIP` corresponde en el histórico a variantes como:

- `M12L DIV`
- `M12L-DIV`

La aplicación las integra bajo `M12L-DIV`. Con esta normalización el modelo reúne aproximadamente 1.861 especímenes válidos.

## Ejemplo de cálculo de compresión

Condición:

- Modelo: `M12L-DIV`
- Absorción objetivo: `6,0 %`

Resultados de referencia del algoritmo:

| Escenario | Masa seca (kg) | Masa saturada (kg) | Masa inmersa (kg) | Masa natural (kg) |
|---|---:|---:|---:|---:|
| Bajo P15 | 10,460 | 11,088 | 5,868 | 10,890 |
| Típico P50 | 10,710 | 11,353 | 6,073 | 11,150 |
| Alto P85 | 10,980 | 11,639 | 6,399 | 11,639 |

## Ejemplo de cálculo de flexotracción

Condición:

- Modelo: `AR8`
- Espesor objetivo: `82 mm`
- Absorción objetivo: `6,0 %`

Resultados de referencia:

| Escenario | Masa seca (g) | Masa saturada (g) | Masa inmersa (g) |
|---|---:|---:|---:|
| Bajo P15 | 3.126 | 3.313 | 1.747 |
| Típico P50 | 3.171 | 3.361 | 1.782 |
| Alto P85 | 3.222 | 3.416 | 1.843 |

Estos valores no están codificados en la aplicación. Se recalculan desde la base SQLite después de importar el histórico.
