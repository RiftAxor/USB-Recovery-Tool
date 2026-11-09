@echo off
chcp 65001 > nul
setlocal

:: Verificar permisos de administrador
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Solicitando permisos de Administrador para gestionar discos...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: Ejecutar el script PowerShell
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Recuperar_USB.ps1"

exit /b
