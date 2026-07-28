@echo off
setlocal
cd /d "%~dp0"
echo Limpiando compilacion anterior...
call flutter clean
if errorlevel 1 goto :error
echo Obteniendo dependencias...
call flutter pub get
if errorlevel 1 goto :error
echo Iniciando MasaLab Historico en Windows...
call flutter run -d windows
if errorlevel 1 goto :error
goto :end
:error
echo.
echo Ocurrio un error durante la actualizacion o ejecucion.
pause
exit /b 1
:end
endlocal
