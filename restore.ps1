# ========================================================
# Universal Antigravity Restore Script for Windows
# Restores any modified components from .bak files
# ========================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "restore.log"

function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue

    switch ($Level) {
        "INFO"    { Write-Host "  [*] $Message" -ForegroundColor $Color }
        "SUCCESS" { Write-Host "  [+] $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "  [!] $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "  [X] $Message" -ForegroundColor Red }
        "HEADER"  { Write-Host "$Message" -ForegroundColor $Color }
        default   { Write-Host "  $Message" -ForegroundColor $Color }
    }
}

Log-Message "========================================================" -Level "HEADER" -Color Yellow
Log-Message "   ОТКАТ И ВОССТАНОВЛЕНИЕ ИЗ БЭКАПОВ                    " -Level "HEADER" -Color Yellow
Log-Message "========================================================" -Level "HEADER" -Color Yellow
Write-Host ""

# Закрытие запущенных процессов
$procNames = @("Antigravity IDE", "Antigravity", "antigravity-ide", "antigravity", "language_server", "agy")
$foundProcs = Get-Process -Name $procNames -ErrorAction SilentlyContinue
if ($foundProcs) {
    Log-Message "Завершение запущенных процессов Antigravity..." -Level "WARN"
    foreach ($p in $foundProcs) {
        try { $p | Stop-Process -Force -ErrorAction Stop } catch {}
    }
    Start-Sleep -Seconds 2
}

$restoredCount = 0

function Restore-File {
    param ([string]$OrigPath, [string]$Title)
    $bak = "$OrigPath.bak"
    if (Test-Path $bak -PathType Leaf) {
        try {
            Copy-Item -Path $bak -Destination $OrigPath -Force -ErrorAction Stop
            Log-Message "[$Title] Успешно восстановлен из $bak" -Level "SUCCESS"
            return $true
        } catch {
            Log-Message "[$Title] Ошибка восстановления: $_" -Level "ERROR"
            return $false
        }
    }
    return $false
}

# 1. IDE main.js
$idePaths = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Antigravity IDE\resources\app\out\main.js"),
    (Join-Path $env:ProgramFiles "Antigravity IDE\resources\app\out\main.js"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity IDE\resources\app\out\main.js")
)
foreach ($p in $idePaths) {
    if (Restore-File $p "Antigravity IDE") { $restoredCount++ }
}

# 2. 2.0 language_server.exe
$mgrPaths = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Antigravity\resources\bin\language_server.exe"),
    (Join-Path $env:ProgramFiles "Antigravity\resources\bin\language_server.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity\resources\bin\language_server.exe")
)
foreach ($p in $mgrPaths) {
    if (Restore-File $p "Antigravity 2.0") { $restoredCount++ }
}

# 3. CLI agy.exe
$agyPaths = @(
    (Join-Path $env:LOCALAPPDATA "agy\bin\agy.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\agy\bin\agy.exe"),
    (Join-Path $env:USERPROFILE ".gemini\bin\antigravity.exe")
)
foreach ($p in $agyPaths) {
    if (Restore-File $p "Antigravity CLI") { $restoredCount++ }
}

# 4. VS Code extension
$vscodeExtDir = Join-Path $env:USERPROFILE ".vscode\extensions"
if (Test-Path $vscodeExtDir) {
    $matches = Get-ChildItem -Path $vscodeExtDir -Directory -Filter "google.google-antigravity-*" -ErrorAction SilentlyContinue
    foreach ($m in $matches) {
        $p = Join-Path $m.FullName "out\extension.js"
        if (Restore-File $p "VS Code Extension") { $restoredCount++ }
    }
}

# Очистка кэша
$cacheDirs = @(
    (Join-Path $env:APPDATA "Antigravity IDE\CachedData"),
    (Join-Path $env:APPDATA "Antigravity IDE\Code Cache\js")
)
foreach ($cd in $cacheDirs) {
    if (Test-Path $cd) { Remove-Item $cd -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($restoredCount -gt 0) {
    Log-Message "Восстановление успешно завершено! Восстановлено компонентов: $restoredCount" -Level "SUCCESS"
} else {
    Log-Message "Файлы резервных копий (.bak) не обнаружены." -Level "WARN"
}
Log-Message "Лог отката записан в: $LogFile" -Level "INFO"
Write-Host ""
