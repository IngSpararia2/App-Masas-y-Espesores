# Guía rápida: Windows y APK

## Requisitos

1. Flutter 3.38 o superior en `PATH`.
2. Android Studio con Android SDK para generar APK.
3. Visual Studio 2022 con la carga **Desktop development with C++** para abrir la aplicación en Windows.

Compruebe la instalación con:

```powershell
flutter doctor
```

## Primera preparación

Extraiga el ZIP en una carpeta corta, por ejemplo:

```text
C:\Proyectos\masalab_historico
```

Después haga doble clic en:

```text
PREPARAR_PROYECTO.bat
```

Este paso genera las carpetas nativas `android` y `windows` con la versión de Flutter instalada y descarga las dependencias.

## Abrir la aplicación en la PC

Haga doble clic en:

```text
INICIAR_EN_WINDOWS.bat
```

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


## Actualizar el importador XLSX

Si recibió el parche 0.1.3, extraiga su contenido sobre el proyecto y ejecute:

```bat
ACTUALIZAR_IMPORTADOR.bat
```

El script limpia la compilación, actualiza las dependencias e inicia la aplicación. No elimina la base SQLite local.

## Crédito visible

La versión 0.1.4 muestra permanentemente, sobre la barra de navegación inferior:

> App desarrollada por Ing. Samuel Parariá - Derechos Reservados
