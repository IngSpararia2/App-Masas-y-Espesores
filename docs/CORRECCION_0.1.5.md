# Corrección 0.1.5 — Compilación Android

## Problema

La compilación Android fallaba porque `file_picker 11.0.2` no producía la clase nativa `FilePickerPlugin` bajo la configuración actual de Android Gradle Plugin/Kotlin.

## Cambio aplicado

- Se reemplazó `file_picker` por `file_selector 1.1.0`.
- `file_selector` es mantenido por el equipo de Flutter y funciona en Android y Windows.
- Se mantuvo la selección múltiple de archivos `.xlsx`.
- El importador continúa leyendo los archivos como bytes, por lo que no cambia la lógica de importación ni la base SQLite.
- El script `scripts/build_apk.ps1` ahora comprueba el código de salida y solo muestra que el APK fue generado cuando realmente existe.

## Después de aplicar el parche

Ejecutar:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

No se debe editar `GeneratedPluginRegistrant.java`, porque Flutter lo genera automáticamente.
