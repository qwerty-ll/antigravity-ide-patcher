@echo off
chcp 65001 >nul
title Antigravity Patcher for Windows

cd /d "%~dp0"

echo ========================================================
echo   Universal Antigravity Patcher (Windows)
echo ========================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch.ps1"

echo.
pause
