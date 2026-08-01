@echo off
chcp 65001 >nul
setlocal
title MasaLab - Reparar Windows
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\repair_windows.ps1"

if errorlevel 1 (
  echo.
  echo No se pudo reparar Windows. Revise el error mostrado arriba.
  pause
  exit /b 1
)

echo.
pause
