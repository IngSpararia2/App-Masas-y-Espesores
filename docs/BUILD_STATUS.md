# Estado de validación del proyecto

## Verificado en este entorno

- Lectura estructural de los dos XLSX suministrados.
- Comprobación del lector XLSX 0.1.3 sobre la estructura real de ambos libros: 0 celdas de error en compresión y 7 celdas de error controlables en flexotracción.
- Correspondencia de encabezados de compresión y flexotracción con el importador.
- Recuento de especímenes, registros válidos y duplicados internos.
- Ecuaciones de absorción, densidad, masa saturada e inmersa.
- Escalado por espesor y escenarios P15/P50/P85 sobre datos reales.
- Integridad léxica de los archivos Dart: delimitadores, cadenas y comentarios.
- Resolución de importaciones relativas entre archivos del proyecto.
- Sintaxis del esquema SQLite, consulta agregada y respaldo con `VACUUM INTO`.
- Estructura JSON de la configuración de VS Code.

## Validación pendiente en el equipo de desarrollo

Este entorno no dispone del SDK de Flutter, Android SDK ni toolchain de Windows. Por ello, la compilación nativa se ejecuta en el equipo del usuario mediante:

```powershell
.\scripts\bootstrap_flutter.ps1
.\scripts\run_tests.ps1
.\scripts\run_windows.ps1
.\scripts\build_apk.ps1
```

El primer script genera las carpetas nativas a partir de Flutter 3.38 o superior, evitando fijar plantillas Gradle/CMake obsoletas en el ZIP.
