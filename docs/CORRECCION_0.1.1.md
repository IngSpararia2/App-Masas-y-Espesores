# Corrección 0.1.1 — compatibilidad con file_picker 11

## Error corregido

La versión 11 de `file_picker` cambió su API pública de un acceso mediante instancia a métodos estáticos.

Código anterior:

```dart
final result = await FilePicker.platform.pickFiles(
```

Código corregido:

```dart
final result = await FilePicker.pickFiles(
```

## Aplicar la corrección en un proyecto ya preparado

1. Abra `lib/services/app_controller.dart`.
2. Sustituya `FilePicker.platform.pickFiles(` por `FilePicker.pickFiles(`.
3. Desde la carpeta del proyecto ejecute:

```powershell
flutter clean
flutter pub get
flutter run -d windows
```

Los mensajes que indican que existen paquetes más recientes son informativos y no impiden la compilación.
