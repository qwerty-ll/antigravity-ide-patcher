# ========================================================
# Antigravity IDE Restore Script for Windows
# Restores main.js from main.js.bak
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
        default   { Write-Host "  $Message" -ForegroundColor $Color }
    }
}

Log-Message "Поиск установки Antigravity IDE для отката..." -Level "INFO" -Color Cyan

$candidatePaths = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Antigravity IDE\resources\app\out\main.js"),
    (Join-Path $env:ProgramFiles "Antigravity IDE\resources\app\out\main.js"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity IDE\resources\app\out\main.js"),
    (Join-Path $env:USERPROFILE "AppData\Local\Programs\Antigravity IDE\resources\app\out\main.js")
)

$targetJs = $null
foreach ($path in $candidatePaths) {
    if ($path -and (Test-Path -Path $path -PathType Leaf)) {
        $targetJs = (Resolve-Path $path).Path
        break
    }
}

if (-not $targetJs) {
    $userInput = Read-Host "  Введите путь к main.js"
    if ($userInput) { $targetJs = $userInput.Trim('"', "'", " ") }
}

if (-not $targetJs -or -not (Test-Path $targetJs)) {
    Log-Message "Файл main.js не найден." -Level "ERROR"
    exit 1
}

$backupPath = "$targetJs.bak"
if (-not (Test-Path $backupPath -PathType Leaf)) {
    Log-Message "Файл бэкапа не найден: $backupPath" -Level "ERROR"
    exit 1
}

# Закрытие процессов
$procs = Get-Process -Name @("Antigravity IDE", "Antigravity", "antigravity-ide") -ErrorAction SilentlyContinue
if ($procs) {
    Log-Message "Закрытие запущенных процессов Antigravity..." -Level "WARN"
    $procs | Stop-Process -Force
    Start-Sleep -Seconds 1
}

try {
    Copy-Item -Path $backupPath -Destination $targetJs -Force -ErrorAction Stop
    Log-Message "Оригинальный файл успешно восстановлен из бэкапа: $backupPath" -Level "SUCCESS"
} catch {
    Log-Message "Ошибка восстановления: $_" -Level "ERROR"
    exit 1
}

# Очистка кэша
$cacheFolders = @(
    (Join-Path $env:APPDATA "Antigravity IDE\CachedData"),
    (Join-Path $env:APPDATA "Antigravity IDE\Code Cache\js")
)
foreach ($dir in $cacheFolders) {
    if (Test-Path $dir) {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Log-Message "Кэш компиляции очищен. Восстановление завершено!" -Level "SUCCESS"
