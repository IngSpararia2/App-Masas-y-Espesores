@echo off
chcp 65001 >nul
setlocal
title MasaLab - Pruebas
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\run_tests.ps1"

if errorlevel 1 (
  echo.
  echo Las pruebas terminaron con errores. Revise el mensaje mostrado arriba.
  pause
  exit /b 1
)

echo.
echo Analisis y pruebas completados correctamente.
pause
