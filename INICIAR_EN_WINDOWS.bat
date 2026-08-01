@echo off
chcp 65001 >nul
setlocal
title MasaLab - Windows
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\run_windows.ps1"

if errorlevel 1 (
  echo.
  echo No se pudo iniciar MasaLab. Revise el error mostrado arriba.
  pause
  exit /b 1
)

echo.
echo MasaLab se cerró correctamente.
pause
