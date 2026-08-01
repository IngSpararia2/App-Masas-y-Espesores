# Historial de cambios

Este archivo consolida las notas que antes estaban repartidas entre varios
documentos y lanzadores temporales de actualización.

## Próxima versión

- Se añadieron los modos **Precisión** y **Ensayos** a la calculadora.
- Se incorporaron muestras, contra-muestras, límites configurables y generación
  aleatoria para el apoyo de ensayos de laboratorio.
- Se actualizaron el icono y las pantallas de inicio de Android y Windows.
- Los scripts detectan Flutter aunque no esté en `PATH` y usan cachés en la
  unidad de datos, fuera del repositorio, lo que permite trabajar desde D: sin
  llenar C: ni ralentizar el análisis.
- Se retiraron los lanzadores de parches antiguos y la documentación duplicada.

## 0.1.5+6

- Se sustituyó `file_picker` por `file_selector` para recuperar la compilación
  Android y conservar la selección múltiple de archivos XLSX.
- La generación del APK ahora valida el código de salida y la existencia del
  archivo resultante.

## 0.1.4+5

- Se añadió el crédito permanente del desarrollador sobre la navegación.

## 0.1.3+4

- Se reemplazó la dependencia `excel` por un lector XLSX propio y tolerante a
  celdas de error como `#DIV/0!` y `#VALUE!`.

## 0.1.2+3

- La reparación de Windows conserva `Runner.rc` con una codificación compatible
  con `rc.exe`, evitando los errores `RC2135` y `RC2164`.

## 0.1.1+2

- Se adaptó temporalmente la integración a la API estática de `file_picker 11`.
