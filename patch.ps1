# ========================================================
# Antigravity IDE Patcher for Windows
# Bypasses region lock (isGoogleInternal -> true)
# Compatible with Windows PowerShell 5.1+ and PowerShell 7+
# ========================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "patch.log"

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

# Инициализация лог-файла
"========================================================" | Out-File -FilePath $LogFile -Encoding UTF8
"Antigravity IDE Patch Log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $LogFile -Append -Encoding UTF8
"OS: $([System.Environment]::OSVersion.VersionString) ($([System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')))" | Out-File -FilePath $LogFile -Append -Encoding UTF8
"========================================================" | Out-File -FilePath $LogFile -Append -Encoding UTF8

Log-Message "========================================================" -Level "HEADER" -Color Cyan
Log-Message "   Antigravity IDE Patcher (Windows 1-Click)             " -Level "HEADER" -Color Green
Log-Message "========================================================" -Level "HEADER" -Color Cyan
Write-Host ""

# 1. Поиск Antigravity IDE
Log-Message "Поиск установки Antigravity IDE..." -Level "INFO" -Color Cyan

$candidatePaths = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Antigravity IDE\resources\app\out\main.js"),
    (Join-Path $env:ProgramFiles "Antigravity IDE\resources\app\out\main.js"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity IDE\resources\app\out\main.js"),
    (Join-Path $env:LOCALAPPDATA "Programs\antigravity ide\resources\app\out\main.js"),
    (Join-Path $env:ProgramFiles "antigravity ide\resources\app\out\main.js"),
    (Join-Path $env:USERPROFILE "AppData\Local\Programs\Antigravity IDE\resources\app\out\main.js")
)

$targetJs = $null
foreach ($path in $candidatePaths) {
    if ($path -and (Test-Path -Path $path -PathType Leaf)) {
        $targetJs = (Resolve-Path $path).Path
        Log-Message "Найден файл по стандартному пути: $targetJs" -Level "INFO" -Color Cyan
        break
    }
}

# Если стандартные пути не сработали, проверяем реестр Windows
if (-not $targetJs) {
    Log-Message "Проверка реестра Windows (Uninstall keys)..." -Level "INFO"
    $regRoots = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($regRoot in $regRoots) {
        $installed = Get-ItemProperty $regRoot -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -and ($_.DisplayName -like "*Antigravity IDE*" -or $_.DisplayName -like "*antigravity-ide*")
        }
        foreach ($app in $installed) {
            if ($app.InstallLocation) {
                $check1 = Join-Path $app.InstallLocation "resources\app\out\main.js"
                $check2 = Join-Path $app.InstallLocation "out\main.js"
                if (Test-Path $check1 -PathType Leaf) {
                    $targetJs = (Resolve-Path $check1).Path
                    Log-Message "Найден файл через реестр: $targetJs" -Level "INFO" -Color Cyan
                    break
                } elseif (Test-Path $check2 -PathType Leaf) {
                    $targetJs = (Resolve-Path $check2).Path
                    Log-Message "Найден файл через реестр: $targetJs" -Level "INFO" -Color Cyan
                    break
                }
            }
        }
        if ($targetJs) { break }
    }
}

# Если всё ещё не найден, просим пользователя указать путь
if (-not $targetJs) {
    Log-Message "Не удалось автоматически найти Antigravity IDE." -Level "WARN"
    Write-Host ""
    Write-Host "  Укажите папку с Antigravity IDE или путь к файлу main.js." -ForegroundColor Yellow
    Write-Host "  Пример: C:\Users\Имя\AppData\Local\Programs\Antigravity IDE" -ForegroundColor DarkGray
    Write-Host ""
    $userInput = Read-Host "  Путь к Antigravity IDE или main.js"
    if ($userInput) {
        $cleaned = $userInput.Trim('"', "'", " ")
        if (Test-Path $cleaned) {
            if (Test-Path $cleaned -PathType Container) {
                $try1 = Join-Path $cleaned "resources\app\out\main.js"
                $try2 = Join-Path $cleaned "out\main.js"
                $try3 = Join-Path $cleaned "main.js"
                if (Test-Path $try1 -PathType Leaf) { $targetJs = (Resolve-Path $try1).Path }
                elseif (Test-Path $try2 -PathType Leaf) { $targetJs = (Resolve-Path $try2).Path }
                elseif (Test-Path $try3 -PathType Leaf) { $targetJs = (Resolve-Path $try3).Path }
            } elseif (Test-Path $cleaned -PathType Leaf) {
                $targetJs = (Resolve-Path $cleaned).Path
            }
        }
    }
}

if (-not $targetJs -or -not (Test-Path $targetJs -PathType Leaf)) {
    Log-Message "Файл main.js не найден. Патч не может быть выполнен." -Level "ERROR"
    Log-Message "Лог сохранен в: $LogFile" -Level "INFO"
    exit 1
}

Log-Message "Целевой файл: $targetJs" -Level "SUCCESS"
$fileInfo = Get-Item $targetJs
Log-Message "Размер файла: $([math]::Round($fileInfo.Length / 1MB, 2)) MB ($($fileInfo.Length) байт)" -Level "INFO"

# 2. Закрытие запущенных процессов Antigravity
Log-Message "Проверка запущенных процессов Antigravity..." -Level "INFO"
$procNames = @("Antigravity IDE", "Antigravity", "antigravity-ide", "antigravity")
$foundProcs = Get-Process -Name $procNames -ErrorAction SilentlyContinue
if ($foundProcs) {
    Log-Message "Обнаружены запущенные процессы Antigravity. Завершение..." -Level "WARN"
    foreach ($p in $foundProcs) {
        try {
            $p | Stop-Process -Force -ErrorAction Stop
            Log-Message "Завершен процесс: $($p.Name) (PID: $($p.Id))" -Level "INFO"
        } catch {
            Log-Message "Не удалось завершить процесс $($p.Name): $_" -Level "WARN"
        }
    }
    Start-Sleep -Seconds 2
} else {
    Log-Message "Запущенных процессов Antigravity не обнаружено." -Level "INFO"
}

# 3. Чтение файла
Log-Message "Чтение main.js..." -Level "INFO"
try {
    $content = [System.IO.File]::ReadAllText($targetJs, [System.Text.Encoding]::UTF8)
} catch {
    Log-Message "Ошибка чтения файла: $_" -Level "ERROR"
    exit 1
}

# 4. Проверка патча
$pattern = '(resetIsTierGCPTos\(\),)this\.[A-Za-z_$0-9]+\.isGoogleInternal'
$alreadyPatchedMarker = 'resetIsTierGCPTos(),true'
$regex = [regex]$pattern

$hasPatchedMarker = $content.Contains($alreadyPatchedMarker)
$hasUnpatchedPattern = $regex.IsMatch($content)

if ($hasPatchedMarker -and -not $hasUnpatchedPattern) {
    Log-Message "Файл уже пропатчен ($alreadyPatchedMarker обнаружен)!" -Level "SUCCESS"
    Write-Host ""
    $reapply = Read-Host "  Хотите применить патч повторно? (y/N)"
    if ($reapply -ne "y" -and $reapply -ne "Y" -and $reapply -ne "д" -and $reapply -ne "Д") {
        Log-Message "Повторное применение отменено пользователем." -Level "INFO"
        exit 0
    }
}

if (-not $hasUnpatchedPattern -and -not $hasPatchedMarker) {
    Log-Message "Сигнатура патча isGoogleInternal не найдена в файле. Возможно, у вас неподдерживаемая версия Antigravity." -Level "ERROR"
    Log-Message "Проверьте версию Antigravity IDE (требуется >= 2.1.1)." -Level "INFO"
    exit 1
}

# 5. Создание бэкапа
$backupPath = "$targetJs.bak"
$timestampBackup = "$targetJs.bak-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"

if (-not (Test-Path $backupPath)) {
    Log-Message "Создание основного бэкапа: $backupPath" -Level "INFO" -Color Cyan
    try {
        Copy-Item -Path $targetJs -Destination $backupPath -Force -ErrorAction Stop
        $bakInfo = Get-Item $backupPath
        Log-Message "Бэкап успешно создан: $($bakInfo.Name) ($([math]::Round($bakInfo.Length / 1MB, 2)) MB)" -Level "SUCCESS"
    } catch {
        Log-Message "Не удалось создать бэкап: $_" -Level "ERROR"
        exit 1
    }
} else {
    Log-Message "Основной бэкап уже существует ($backupPath). Создаем временный архивный бэкап: $timestampBackup" -Level "WARN"
    try {
        Copy-Item -Path $targetJs -Destination $timestampBackup -Force -ErrorAction Stop
        Log-Message "Архивный бэкап создан: $timestampBackup" -Level "INFO"
    } catch {
        Log-Message "Предупреждение: не удалось сохранить архивный бэкап: $_" -Level "WARN"
    }
}

# 6. Применение патча (замена)
Log-Message "Применение патча (isGoogleInternal -> true)..." -Level "INFO" -Color Cyan

$matchesFound = $regex.Matches($content)
Log-Message "Найдено совпадений: $($matchesFound.Count)" -Level "INFO"

$newContent = $regex.Replace($content, '${1}true')

if ($newContent -eq $content) {
    Log-Message "Содержимое не изменилось после применения регулярного выражения." -Level "WARN"
} else {
    # Атомарная запись через временный файл
    $tempFile = "$targetJs.tmp"
    try {
        [System.IO.File]::WriteAllText($tempFile, $newContent, [System.Text.Encoding]::UTF8)
        $tempInfo = Get-Item $tempFile
        if ($tempInfo.Length -lt ($fileInfo.Length - 10000)) {
            throw "Размер временного файла подозрительно мал ($($tempInfo.Length) байт против $($fileInfo.Length) байт)!"
        }
        Move-Item -Path $tempFile -Destination $targetJs -Force -ErrorAction Stop
        Log-Message "Изменения успешно записаны в main.js!" -Level "SUCCESS"
    } catch {
        Log-Message "Ошибка записи пропатченного файла: $_" -Level "ERROR"
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        exit 1
    }
}

# 7. Очистка кэша компиляции Electron/VS Code
Log-Message "Очистка кэша компиляции Antigravity IDE (CachedData & Code Cache)..." -Level "INFO"
$cacheFolders = @(
    (Join-Path $env:APPDATA "Antigravity IDE\CachedData"),
    (Join-Path $env:APPDATA "Antigravity IDE\Code Cache\js"),
    (Join-Path $env:APPDATA "antigravity-ide\CachedData"),
    (Join-Path $env:APPDATA "antigravity-ide\Code Cache\js")
)

$clearedCount = 0
foreach ($dir in $cacheFolders) {
    if (Test-Path $dir) {
        try {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
            Log-Message "Удален кэш: $dir" -Level "INFO"
            $clearedCount++
        } catch {
            Log-Message "Не удалось полностью очистить $dir: $_" -Level "WARN"
        }
    }
}
if ($clearedCount -gt 0) {
    Log-Message "Кэш компиляции успешно сброшен." -Level "SUCCESS"
} else {
    Log-Message "Кэш компиляции пуст или не требовал очистки." -Level "INFO"
}

# 8. Итоговый отчет
Write-Host ""
Log-Message "========================================================" -Level "HEADER" -Color Green
Log-Message "   ПАТЧ УСПЕШНО ПРИМЕНЕН!                               " -Level "HEADER" -Color Green
Log-Message "========================================================" -Level "HEADER" -Color Green
Log-Message "1. Бэкап сохранен: $backupPath" -Level "INFO"
Log-Message "2. Лог операции сохранен: $LogFile" -Level "INFO"
Log-Message "3. Теперь можно запустить Antigravity IDE и войти в аккаунт." -Level "SUCCESS"
Write-Host ""
