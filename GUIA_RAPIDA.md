# Guía rápida: Windows y APK

## Requisitos

1. Flutter 3.38 o superior en `PATH`, `FLUTTER_ROOT` o dentro de
   `%USERPROFILE%\flutter\<version>`.
2. Android Studio con Android SDK para generar APK.
3. Visual Studio actualizado con la carga **Desktop development with C++** para
   abrir la aplicación en Windows.

Si Flutter está en `PATH`, compruebe la instalación manualmente con:

```powershell
flutter doctor -v
```

## Ubicación del proyecto

El repositorio puede estar en C: o D:. Se recomienda una ruta corta, por ejemplo:

```text
D:\Samuel\App-Masas-y-Espesores
```

Las carpetas `android` y `windows` ya vienen incluidas. No ejecute una preparación
destructiva para el uso normal. `PREPARAR_PROYECTO.bat` queda reservado para
recuperar una plataforma nativa ausente o dañada.

## Abrir la aplicación en la PC

Haga doble clic en:

```text
INICIAR_EN_WINDOWS.bat
```

El iniciador localiza Flutter automáticamente, guarda las cachés grandes en la
misma unidad pero fuera del repositorio y comprueba que Visual Studio tenga las
herramientas C++ necesarias.

Luego, dentro de la aplicación, abra **Importar** y seleccione uno o ambos archivos XLSX.

## Generar el APK

Haga doble clic en:

```text
GENERAR_APK.bat
```

El archivo resultante queda en:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Puede copiar ese APK al celular Android e instalarlo. Android puede solicitar autorización para instalar aplicaciones desde esa fuente. Este APK sirve para pruebas e instalación directa; para publicar en Google Play debe configurar una clave de firma propia.

## Verificación del código

Haga doble clic en:

```text
EJECUTAR_PRUEBAS.bat
```

Se ejecutan `flutter analyze` y las pruebas automatizadas del algoritmo.


## Reparar errores de `Runner.rc` en Windows

Si aparecen errores `RC2135` o `RC2164` relacionados con `Runner.rc`, ejecute:

```bat
REPARAR_WINDOWS.bat
```

Después vuelva a ejecutar:

```bat
INICIAR_EN_WINDOWS.bat
```


## Crédito visible

La versión 0.1.4 muestra permanentemente, sobre la barra de navegación inferior:

> App desarrollada por Ing. Samuel Parariá - Derechos Reservados
