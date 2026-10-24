@echo off
chcp 65001 >nul
title Restore Antigravity IDE Backup

cd /d "%~dp0"

echo ========================================================
echo   Antigravity IDE Restore (Откат бэкапа)
echo ========================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1"

echo.
echo Нажмите любую клавишу для выхода...
pause >nul
