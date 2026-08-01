@echo off
chcp 65001 >nul
setlocal
title MasaLab - Preparar proyecto
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\bootstrap_flutter.ps1"

if errorlevel 1 (
  echo.
  echo No se pudo preparar el proyecto. Revise el error mostrado arriba.
  pause
  exit /b 1
)

echo.
pause
