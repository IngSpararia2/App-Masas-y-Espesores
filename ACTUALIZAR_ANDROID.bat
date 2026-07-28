@echo off
chcp 65001 >nul
title Actualizar compilación Android - MasaLab
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\update_android.ps1"
if errorlevel 1 (
  echo.
  echo La actualización o compilación terminó con errores.
  pause
  exit /b 1
)
echo.
echo Actualización terminada correctamente.
pause
