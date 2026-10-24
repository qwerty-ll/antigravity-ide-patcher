@echo off
chcp 65001 >nul
title Restore Antigravity Backup

cd /d "%~dp0"

echo ========================================================
echo   Antigravity Restore (Windows)
echo ========================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1"

echo.
pause
