@echo off
chcp 65001 >nul
setlocal
title MasaLab - Generar APK
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\build_apk.ps1"

if errorlevel 1 (
  echo.
  echo No se pudo generar el APK. Revise el error mostrado arriba.
  pause
  exit /b 1
)

echo.
pause
