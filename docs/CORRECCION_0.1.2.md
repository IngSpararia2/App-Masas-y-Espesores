# Corrección 0.1.2 — Runner.rc en Windows

## Síntoma

La compilación de Windows presenta errores como:

- `RC2135: file not found: 0x09`
- `RC2135: file not found: FILEOS`
- `RC2135: file not found: BLOCK`
- `RC2135: file not found: VALUE`
- `RC2164: unexpected value in RCDATA`

## Causa

El script de preparación anterior modificaba `windows/runner/Runner.rc` y lo
volvía a guardar mediante `Set-Content -Encoding UTF8`. En Windows PowerShell
5.1 esta operación puede cambiar la codificación del archivo. El compilador de
recursos `rc.exe` incluido con Visual Studio 2019 puede interpretar entonces las
directivas del recurso como si fueran identificadores o nombres de archivos.

No es un error del código Dart ni de las dependencias descargadas.

## Solución incorporada

La versión 0.1.2:

1. deja `Runner.rc` exactamente como lo genera Flutter;
2. elimina la personalización insegura del archivo de recursos;
3. usa texto ASCII y una secuencia Unicode de C++ para el título de la ventana;
4. incluye `REPARAR_WINDOWS.bat`, que elimina y regenera únicamente la
   plataforma Windows y limpia la compilación anterior.

## Uso

Ejecute primero:

```bat
REPARAR_WINDOWS.bat
```

Luego:

```bat
INICIAR_EN_WINDOWS.bat
```

Como alternativa manual:

```powershell
Remove-Item windows -Recurse -Force
Remove-Item build -Recurse -Force -ErrorAction SilentlyContinue
flutter create --platforms=windows --org com.samuelpararia --project-name masalab_historico .
flutter clean
flutter pub get
flutter run -d windows
```
