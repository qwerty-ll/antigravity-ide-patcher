@echo off
chcp 65001 >nul
title Antigravity IDE Patcher for Windows

cd /d "%~dp0"

echo ========================================================
echo   Antigravity IDE 1-Click Patcher (Windows)
echo ========================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch.ps1"
set EXIT_CODE=%ERRORLEVEL%

echo.
if %EXIT_CODE% equ 0 (
    echo [OK] Операция завершена успешно.
) else (
    echo [X] В процессе возникли ошибки. Код завершения: %EXIT_CODE%.
    echo [i] Пожалуйста, проверьте файл patch.log рядом со скриптом.
)

echo.
echo Нажмите любую клавишу для выхода...
pause >nul
exit /b %EXIT_CODE%
