@echo off
setlocal
cd /d "%~dp0"
chcp 65001 >nul

echo Actualizando dependencias y limpiando la compilacion...
flutter clean
if errorlevel 1 goto :error

flutter pub get
if errorlevel 1 goto :error

echo.
echo Iniciando MasaLab Historico en Windows...
flutter run -d windows
if errorlevel 1 goto :error

goto :end

:error
echo.
echo La actualizacion no termino correctamente. Revise el mensaje anterior.

:end
echo.
pause
