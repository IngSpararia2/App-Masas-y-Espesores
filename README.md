# MasaLab Histórico

Aplicación Flutter offline para importar históricos de **compresión** y **flexotracción**, mantenerlos en SQLite sin duplicados y estimar masas físicamente coherentes por modelo.

## Por qué Flutter

Flutter permite mantener una sola base de código para Android y Windows. En este proyecto se usa:

- Flutter/Material 3 para la interfaz.
- SQLite mediante `sqlite3` para persistencia local en Android y Windows.
- `file_picker` para seleccionar uno o varios archivos XLSX.
- Un lector XLSX tabular propio, basado en `archive` y `xml`, para leer la hoja `Resumen` y tolerar celdas con errores de fórmula.
- SHA-256 para deduplicación y control de cambios.

Referencias oficiales:

- https://docs.flutter.dev/platform-integration/desktop
- https://docs.flutter.dev/platform-integration/android/setup
- https://docs.flutter.dev/deployment/android
- https://pub.dev/packages/sqlite3
- https://pub.dev/packages/file_picker
- https://pub.dev/packages/archive
- https://pub.dev/packages/xml

## Funciones implementadas

### Importación

- Selección simultánea de uno o varios archivos `.xlsx`.
- Detección automática de resumen de compresión o flexotracción.
- Extracción de hasta 3 bloques por fila de compresión.
- Extracción de hasta 5 muestras por fila de flexotracción.
- Persistencia en SQLite.
- Inserción de registros nuevos.
- Actualización de registros cuyo contenido cambió.
- Omisión de registros idénticos.
- Detección de archivos exactos ya importados mediante SHA-256.
- Normalización de modelos y alias.
- Recalculo de absorción y densidad desde las masas.
- Marcado de datos físicamente incoherentes para excluirlos de la predicción.
- Omisión controlada de celdas de Excel con errores como `#DIV/0!` y `#VALUE!`, sin detener la importación.

### Cálculo

**Compresión**

Entrada:

- Modelo.
- Absorción objetivo.

Salida:

- Masa seca.
- Masa saturada.
- Masa inmersa.
- Masa natural.
- Tres escenarios: bajo (P15), típico (P50) y alto (P85).

**Flexotracción**

Entrada:

- Modelo.
- Absorción objetivo.
- Espesor objetivo en milímetros.

Salida:

- Masa seca.
- Masa saturada.
- Masa inmersa.
- Tres escenarios: bajo, típico y alto.

La masa seca se escala con `masa seca histórica / espesor histórico`, por lo que el resultado cambia de forma proporcional y coherente con el espesor solicitado.

### Administración

- Resumen de registros, datos válidos y modelos.
- Historial de importaciones.
- Respaldo de la base SQLite.
- Reinicio controlado de la base.

## Hallazgos de los archivos analizados

- El resumen de compresión contiene 2.908 filas de datos y hasta 3 especímenes por fila.
- El resumen de flexotracción contiene 1.020 filas de datos y hasta 5 especímenes por fila.
- En el archivo actual de flexotracción, los valores rotulados como `Densidad` y `Absorcion` aparecen intercambiados en numerosos registros. La aplicación no confía en esas columnas: recalcula ambos parámetros usando las masas.
- Variantes como `M12L DIV`, `M12L-DIV` y la forma indicada `M12L-DIP` se agrupan bajo `M12L-DIV`.

## Preparar el proyecto en Windows

El ZIP contiene todo el código de la aplicación. Las carpetas nativas `android` y `windows` se generan con la plantilla de la versión de Flutter que tenga instalada; esto evita entregar archivos Gradle o CMake que queden obsoletos.

### 1. Instalar herramientas

Instale:

- Flutter **3.38 o superior** y agréguelo a `PATH`.
- Android Studio con Android SDK para compilar APK.
- Visual Studio 2022 con **Desktop development with C++** para ejecutar la versión Windows.

Verifique:

```powershell
flutter doctor
```

### 2. Generar las plataformas y descargar dependencias

Abra PowerShell en la carpeta del proyecto:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\bootstrap_flutter.ps1
```

## Previsualizar en la PC

```powershell
.\scripts\run_windows.ps1
```

Comando equivalente:

```powershell
flutter run -d windows
```

La aplicación abre como programa de Windows y utiliza la misma lógica y base local que Android. Los históricos XLSX se importan desde la propia interfaz; no están incrustados en el proyecto.

## Generar el APK

APK universal, más sencillo para instalar manualmente:

```powershell
.\scripts\build_apk.ps1
```

Se genera en:

```text
build\app\outputs\flutter-apk\app-release.apk
```

APK separados por arquitectura, de menor tamaño:

```powershell
.\scripts\build_apk.ps1 -SplitPerAbi
```

Para probar directamente por USB:

```powershell
flutter devices
flutter run -d <ID_DEL_CELULAR>
```

## Uso inicial

1. Abra **Importar**.
2. Seleccione `Resumen_Compresion.xlsx`, `Resumen_Flexotraccion.xlsx` o ambos.
3. Espere el resumen de nuevos, actualizados, sin cambios y rechazados.
4. Abra **Calcular**.
5. Elija compresión o flexotracción y seleccione un modelo.
6. Indique absorción y, para flexotracción, espesor.
7. Revise los escenarios y las advertencias de extrapolación.

## Pruebas y análisis estático

```powershell
.\scripts\run_tests.ps1
```

O manualmente:

```powershell
flutter analyze
flutter test
```

## Estructura

```text
lib/
  core/                 modelos, normalización y estadística robusta
  data/                 SQLite y consultas
  services/             importación, predicción y controlador
  ui/                    interfaz Material 3
docs/
  ALGORITHM.md           fundamento matemático
  DATABASE.md            esquema y deduplicación
  ROADMAP.md             ampliaciones sugeridas
  BUILD_STATUS.md        comprobaciones realizadas y compilación pendiente
scripts/                 preparación, ejecución, APK y pruebas
test/                    pruebas de normalización, estadística y ecuaciones
```

## Precaución técnica

Este proyecto fue preparado contra Flutter 3.38+ y sus dependencias actuales. Los resultados son estimaciones derivadas del histórico y sirven para proponer valores realistas de trabajo. No sustituyen el pesaje, la validación de laboratorio, las tolerancias normativas ni el criterio del responsable de calidad.

## Correcciones de versión

- **0.1.1+2:** compatibilidad con la API estática de `file_picker 11.x`. Consulte `docs/CORRECCION_0.1.1.md`.
- **0.1.2+3:** regeneración segura de la plataforma Windows sin corromper `Runner.rc`. Consulte `docs/CORRECCION_0.1.2.md`.
- **0.1.3+4:** lector XLSX tolerante a celdas de error y eliminación de la dependencia `excel`. Consulte `docs/CORRECCION_0.1.3.md`.
- **0.1.4+5:** crédito de autor visible y persistente sobre la barra de navegación. Consulte `docs/CORRECCION_0.1.4.md`.


### Reparación de la plataforma Windows

Ante errores del compilador de recursos `Runner.rc` (`RC2135` o `RC2164`),
ejecute `REPARAR_WINDOWS.bat` y luego `INICIAR_EN_WINDOWS.bat`.
