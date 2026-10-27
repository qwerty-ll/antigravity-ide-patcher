# ========================================================
# Universal Antigravity Patcher for Windows (1-Click)
# Supports:
#   1. Antigravity IDE (Electron main.js -> isGoogleInternal=true)
#   2. Antigravity 2.0 (language_server.exe -> hasValidAuth=true)
#   3. Antigravity CLI (agy.exe -> eligibility=true)
#   4. Google Antigravity VS Code Extension (extension.js)
# Compatible with Windows PowerShell 5.1+ and PowerShell 7+
# ========================================================

param (
    [string]$CustomTarget = ""
)

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
"Universal Antigravity Patch Log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $LogFile -Append -Encoding UTF8
"OS: $([System.Environment]::OSVersion.VersionString) ($([System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')))" | Out-File -FilePath $LogFile -Append -Encoding UTF8
"========================================================" | Out-File -FilePath $LogFile -Append -Encoding UTF8

Log-Message "========================================================" -Level "HEADER" -Color Cyan
Log-Message "   Universal Antigravity Patcher (Windows 1-Click)      " -Level "HEADER" -Color Green
Log-Message "========================================================" -Level "HEADER" -Color Cyan
Write-Host ""

# Результаты патчинга компонентов
$Summary = @{
    "Antigravity IDE"       = "Не найдено"
    "Antigravity 2.0"       = "Не найдено"
    "Antigravity CLI (agy)" = "Не найдено"
    "VS Code Extension"     = "Не найдено"
}

# ---------------------------------------------------------------------------
# Вспомогательная функция: бинарный патч файла
# ---------------------------------------------------------------------------
function Patch-BinaryGate {
    param (
        [string]$FilePath,
        [string]$ComponentTitle,
        [string]$UnpatchedPattern,
        [string]$PatchedPattern,
        [byte[]]$ReplacementBytes,
        [int]$Offset = 0,
        [string]$GateDesc = ""
    )

    if (-not (Test-Path $FilePath -PathType Leaf)) {
        return "not_found"
    }

    Log-Message "[$ComponentTitle] Анализ бинарного файла: $FilePath" -Level "INFO" -Color Cyan
    $fileInfo = Get-Item $FilePath
    Log-Message "[$ComponentTitle] Размер: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -Level "INFO"

    $backupPath = "$FilePath.bak"
    $iso = [System.Text.Encoding]::GetEncoding("iso-8859-1")

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    } catch {
        Log-Message "[$ComponentTitle] Ошибка чтения файла: $_" -Level "ERROR"
        return "read_error"
    }

    $str = $iso.GetString($bytes)

    # Проверка, не пропатчен ли уже
    if ($PatchedPattern) {
        $mPatched = [regex]::Match($str, $PatchedPattern)
        if ($mPatched.Success) {
            Log-Message "[$ComponentTitle] Файл уже пропатчен ($GateDesc)!" -Level "SUCCESS"
            return "already_patched"
        }
    }

    # Поиск unpatched сигнатуры
    $mUnpatched = [regex]::Match($str, $UnpatchedPattern)
    if (-not $mUnpatched.Success) {
        Log-Message "[$ComponentTitle] Сигнатура $GateDesc не найдена (возможно, неподдерживаемая версия)." -Level "WARN"
        return "sig_not_found"
    }

    $writeOffset = $mUnpatched.Index + $Offset
    Log-Message "[$ComponentTitle] Найдена сигнатура на смещении: 0x$($writeOffset.ToString('X8'))" -Level "INFO"

    # Создание бэкапа
    if (-not (Test-Path $backupPath)) {
        try {
            Copy-Item -Path $FilePath -Destination $backupPath -Force -ErrorAction Stop
            Log-Message "[$ComponentTitle] Создан бэкап: $backupPath" -Level "SUCCESS"
        } catch {
            Log-Message "[$ComponentTitle] Ошибка создания бэкапа: $_" -Level "ERROR"
            return "backup_error"
        }
    } else {
        Log-Message "[$ComponentTitle] Бэкап уже существует: $backupPath" -Level "INFO"
    }

    # Модификация байтов
    for ($i = 0; $i -lt $ReplacementBytes.Length; $i++) {
        $bytes[$writeOffset + $i] = $ReplacementBytes[$i]
    }

    # Атомарная запись
    $tempPath = "$FilePath.tmp"
    try {
        [System.IO.File]::WriteAllBytes($tempPath, $bytes)
        $tempInfo = Get-Item $tempPath
        if ($tempInfo.Length -ne $fileInfo.Length) {
            throw "Размер временного файла не совпадает с оригиналом!"
        }
        Move-Item -Path $tempPath -Destination $FilePath -Force -ErrorAction Stop
        Log-Message "[$ComponentTitle] Патч успешно применен ($GateDesc)!" -Level "SUCCESS"
        return "patched"
    } catch {
        Log-Message "[$ComponentTitle] Ошибка записи изменений: $_" -Level "ERROR"
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force -ErrorAction SilentlyContinue }
        return "write_error"
    }
}

# ---------------------------------------------------------------------------
# 1. Завершение запущенных процессов Antigravity
# ---------------------------------------------------------------------------
Log-Message "Проверка и закрытие запущенных процессов..." -Level "INFO"
$procNames = @("Antigravity IDE", "Antigravity", "antigravity-ide", "antigravity", "language_server", "agy")
$foundProcs = Get-Process -Name $procNames -ErrorAction SilentlyContinue
if ($foundProcs) {
    Log-Message "Завершение запущенных процессов Antigravity..." -Level "WARN"
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
    Log-Message "Активных процессов не обнаружено." -Level "INFO"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 2. ПОИСК И ПАТЧ: ANTIGRAVITY IDE (main.js)
# ---------------------------------------------------------------------------
Log-Message "--- Проверка Antigravity IDE (редактор кода) ---" -Level "HEADER" -Color Yellow

$ideCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Antigravity IDE\resources\app\out\main.js"),
    (Join-Path $env:ProgramFiles "Antigravity IDE\resources\app\out\main.js"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity IDE\resources\app\out\main.js"),
    (Join-Path $env:USERPROFILE "AppData\Local\Programs\Antigravity IDE\resources\app\out\main.js")
)

# Проверка реестра для IDE
$regRoots = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($regRoot in $regRoots) {
    $apps = Get-ItemProperty $regRoot -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and ($_.DisplayName -like "*Antigravity IDE*")
    }
    foreach ($app in $apps) {
        if ($app.InstallLocation) {
            $ideCandidates += (Join-Path $app.InstallLocation "resources\app\out\main.js")
            $ideCandidates += (Join-Path $app.InstallLocation "out\main.js")
        }
    }
}

$ideTarget = $null
foreach ($c in $ideCandidates) {
    if ($c -and (Test-Path $c -PathType Leaf)) {
        $ideTarget = (Resolve-Path $c).Path
        break
    }
}

if ($ideTarget) {
    Log-Message "Найден Antigravity IDE: $ideTarget" -Level "INFO" -Color Cyan
    $content = [System.IO.File]::ReadAllText($ideTarget, [System.Text.Encoding]::UTF8)
    $pattern = '(resetIsTierGCPTos\(\),)this\.[A-Za-z_$0-9]+\.isGoogleInternal'
    $alreadyMarker = 'resetIsTierGCPTos(),true'
    $regex = [regex]$pattern

    if ($content.Contains($alreadyMarker) -and -not $regex.IsMatch($content)) {
        Log-Message "Antigravity IDE уже пропатчен (isGoogleInternal=true)!" -Level "SUCCESS"
        $Summary["Antigravity IDE"] = "Уже был пропатчен"
    } elseif ($regex.IsMatch($content)) {
        $bak = "$ideTarget.bak"
        if (-not (Test-Path $bak)) {
            Copy-Item -Path $ideTarget -Destination $bak -Force
            Log-Message "Создан бэкап: $bak" -Level "SUCCESS"
        }
        $newContent = $regex.Replace($content, '${1}true')
        $tmp = "$ideTarget.tmp"
        [System.IO.File]::WriteAllText($tmp, $newContent, [System.Text.Encoding]::UTF8)
        Move-Item -Path $tmp -Destination $ideTarget -Force
        Log-Message "Патч успешно применен к Antigravity IDE!" -Level "SUCCESS"
        $Summary["Antigravity IDE"] = "Успешно пропатчен"

        # Сброс кэша
        $cacheDirs = @(
            (Join-Path $env:APPDATA "Antigravity IDE\CachedData"),
            (Join-Path $env:APPDATA "Antigravity IDE\Code Cache\js")
        )
        foreach ($cd in $cacheDirs) {
            if (Test-Path $cd) { Remove-Item $cd -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Log-Message "Кэш компиляции Antigravity IDE очищен." -Level "INFO"
    } else {
        Log-Message "Сигнатура в main.js не найдена." -Level "WARN"
        $Summary["Antigravity IDE"] = "Сигнатура не найдена"
    }
} else {
    Log-Message "Antigravity IDE не обнаружен на компьютере." -Level "INFO"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 3. ПОИСК И ПАТЧ: ANTIGRAVITY 2.0 (language_server.exe)
# ---------------------------------------------------------------------------
Log-Message "--- Проверка Antigravity 2.0 (language_server.exe) ---" -Level "HEADER" -Color Yellow

$mgrCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Antigravity\resources\bin\language_server.exe"),
    (Join-Path $env:ProgramFiles "Antigravity\resources\bin\language_server.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity\resources\bin\language_server.exe"),
    (Join-Path $env:USERPROFILE "AppData\Local\Programs\Antigravity\resources\bin\language_server.exe"),
    (Join-Path $env:LOCALAPPDATA "Antigravity\resources\bin\language_server.exe")
)

# Проверка реестра для 2.0
foreach ($regRoot in $regRoots) {
    $apps = Get-ItemProperty $regRoot -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and ($_.DisplayName -like "*Antigravity*" -and $_.DisplayName -notlike "*Antigravity IDE*")
    }
    foreach ($app in $apps) {
        if ($app.InstallLocation) {
            $mgrCandidates += (Join-Path $app.InstallLocation "resources\bin\language_server.exe")
        }
    }
}

$mgrTarget = $null
foreach ($m in $mgrCandidates) {
    if ($m -and (Test-Path $m -PathType Leaf)) {
        $mgrTarget = (Resolve-Path $m).Path
        break
    }
}

if ($mgrTarget) {
    Log-Message "Найден Antigravity 2.0 language_server: $mgrTarget" -Level "INFO" -Color Cyan

    # Сигнатуры для x64 и ARM64
    # x64: cmp byte[rax+8],0 ; je short -> mov byte[rax+8],1 ; nop*2
    $x64Unpatched = '\x80\x78\x08\x00\x74[\s\S]\x48\x8b[\s\S]\x24[\s\S]\x48\x89[\s\S]\x60'
    $x64Patched   = '\xc6\x40\x08\x01\x90\x90\x48\x8b[\s\S]\x24[\s\S]\x48\x89[\s\S]\x60'
    $x64Fix       = [byte[]]@(0xC6, 0x40, 0x08, 0x01, 0x90, 0x90)

    # arm64:
    $arm64Unpatched = '\x03\x20\x40\x39[\x03\x23\x43\x63\x83\xa3\xc3\xe3][\s\S]{2}\x36(?:[\s\S]{4}){1,2}\x03\x10\x06\xa9'
    $arm64Patched   = '\x23\x00\x80\x52\x03\x20\x00\x39(?:[\s\S]{4}){1,2}\x03\x10\x06\xa9'
    $arm64Fix       = [byte[]]@(0x23, 0x00, 0x80, 0x52, 0x03, 0x20, 0x00, 0x39)

    $res = Patch-BinaryGate -FilePath $mgrTarget -ComponentTitle "Antigravity 2.0" `
        -UnpatchedPattern $x64Unpatched -PatchedPattern $x64Patched `
        -ReplacementBytes $x64Fix -Offset 0 -GateDesc "hasValidAuth=true (x64)"

    if ($res -eq "sig_not_found") {
        # Попытка для arm64
        $res = Patch-BinaryGate -FilePath $mgrTarget -ComponentTitle "Antigravity 2.0" `
            -UnpatchedPattern $arm64Unpatched -PatchedPattern $arm64Patched `
            -ReplacementBytes $arm64Fix -Offset 0 -GateDesc "hasValidAuth=true (arm64)"
    }

    if ($res -eq "patched") { $Summary["Antigravity 2.0"] = "Успешно пропатчен" }
    elseif ($res -eq "already_patched") { $Summary["Antigravity 2.0"] = "Уже был пропатчен" }
    else { $Summary["Antigravity 2.0"] = "Ошибка ($res)" }
} else {
    Log-Message "Antigravity 2.0 (language_server.exe) не обнаружен." -Level "INFO"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 4. ПОИСК И ПАТЧ: ANTIGRAVITY CLI (agy.exe)
# ---------------------------------------------------------------------------
Log-Message "--- Проверка Antigravity CLI (agy.exe) ---" -Level "HEADER" -Color Yellow

# Проверка сетевой доступности серверов Google
Log-Message "Проверка сетевого доступа к серверам Google..." -Level "INFO"
$googleOk = $false
try {
    $req = [System.Net.HttpWebRequest]::Create("https://antigravity.google")
    $req.Timeout = 3000
    $req.Method = "HEAD"
    $resp = $req.GetResponse()
    $resp.Close()
    $googleOk = $true
    Log-Message "Связь с серверами Google: доступна напрямую." -Level "SUCCESS"
} catch {
    Log-Message "Серверы Google недоступны напрямую без VPN (это стандартно для РФ)." -Level "WARN"
}

# Сигнатуры для CLI и движка
$gateDefinitions = @(
    @{
        Desc      = "eligibility off (x64 near jump)"
        Unpatched = '\x48\x85\xc0\x0f\x84[\s\S]{4}\x80\x78\x08\x00\x0f\x85[\s\S]{4}'
        Patched   = '\x48\x85\xc0\x0f\x84[\s\S]{4}\x48\x85\xc0\x90\x0f\x85[\s\S]{4}'
        Fix       = [byte[]]@(0x48, 0x85, 0xC0, 0x90)
        Offset    = 9
    },
    @{
        Desc      = "eligibility off (x64 short jump)"
        Unpatched = '\x48\x85\xc0\x74[\s\S]\x80\x78\x08\x00(?:\x75[\s\S]|\x0f\x85[\s\S]{4})'
        Patched   = '\x48\x85\xc0\x74[\s\S]\x48\x85\xc0\x90(?:\x75[\s\S]|\x0f\x85[\s\S]{4})'
        Fix       = [byte[]]@(0x48, 0x85, 0xC0, 0x90)
        Offset    = 5
    },
    @{
        Desc      = "hasValidAuth=true (x64 engine/manager)"
        Unpatched = '\x80\x78\x08\x00\x74[\s\S]\x48\x8b[\s\S]\x24[\s\S]\x48\x89[\s\S]\x60'
        Patched   = '\xc6\x40\x08\x01\x90\x90\x48\x8b[\s\S]\x24[\s\S]\x48\x89[\s\S]\x60'
        Fix       = [byte[]]@(0xC6, 0x40, 0x08, 0x01, 0x90, 0x90)
        Offset    = 0
    },
    @{
        Desc      = "eligibility off (arm64)"
        Unpatched = '\x21\x00\x00\x35\x00\x00\x00\xb4\x01\x20\x40\x39\x01\x00\x00\x37'
        Patched   = '\x21\x00\x00\x35\x00\x00\x00\xb4\x1f\x20\x03\xd5\x01\x00\x00\x37'
        Fix       = [byte[]]@(0x1F, 0x20, 0x03, 0xD5)
        Offset    = 8
    },
    @{
        Desc      = "hasValidAuth=true (arm64 engine/manager)"
        Unpatched = '\x03\x20\x40\x39[\x03\x23\x43\x63\x83\xa3\xc3\xe3][\s\S]{2}\x36(?:[\s\S]{4}){1,2}\x03\x10\x06\xa9'
        Patched   = '\x23\x00\x80\x52\x03\x20\x00\x39(?:[\s\S]{4}){1,2}\x03\x10\x06\xa9'
        Fix       = [byte[]]@(0x23, 0x00, 0x80, 0x52, 0x03, 0x20, 0x00, 0x39)
        Offset    = 0
    }
)

$rawAgyCandidates = @()

# 0. Пользовательский путь из аргументов
if ($CustomTarget -and (Test-Path $CustomTarget -PathType Leaf)) {
    $rawAgyCandidates += (Resolve-Path $CustomTarget).Path
}

# 1. Сканирование %LOCALAPPDATA%\agy (включая папку versions)
$agyRoot = Join-Path $env:LOCALAPPDATA "agy"
if (Test-Path $agyRoot) {
    Log-Message "Сканирование каталога: $agyRoot" -Level "INFO"
    $allAgyItems = Get-ChildItem -Path $agyRoot -Recurse -ErrorAction SilentlyContinue
    if ($allAgyItems) {
        foreach ($item in $allAgyItems) {
            if (-not $item.PSIsContainer) {
                $rawAgyCandidates += $item.FullName
                Log-Message "  Обнаружен файл: $($item.FullName) ($([math]::Round($item.Length / 1MB, 2)) MB)" -Level "INFO"
            }
        }
    }
}

# 2. Поиск в %USERPROFILE%\.gemini
$geminiDir = Join-Path $env:USERPROFILE ".gemini"
if (Test-Path $geminiDir) {
    $rawAgyCandidates += (Get-ChildItem -Path $geminiDir -Recurse -Filter "*agy*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $rawAgyCandidates += (Get-ChildItem -Path $geminiDir -Recurse -Filter "*antigravity*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}

# 3. Поиск в других стандартных папках
$additionalDirs = @(
    (Join-Path $env:APPDATA "agy"),
    (Join-Path $env:USERPROFILE ".antigravity"),
    (Join-Path $env:USERPROFILE ".agy"),
    (Join-Path $env:LOCALAPPDATA "Programs\agy"),
    (Join-Path $env:USERPROFILE "scoop\apps\agy")
)
foreach ($dir in $additionalDirs) {
    if (Test-Path $dir) {
        $rawAgyCandidates += (Get-ChildItem -Path $dir -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
}

# 4. Поиск в PATH
foreach ($cmdName in @("agy.exe", "agy", "antigravity.exe", "antigravity")) {
    $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { $rawAgyCandidates += $cmd.Source }
}

# 5. Поиск на диске D: (если есть)
foreach ($dPath in @("D:\agy", "D:\antigravity", "D:\Programs\agy", "D:\яндекс загрузки")) {
    if (Test-Path $dPath) {
        $rawAgyCandidates += (Get-ChildItem -Path $dPath -Recurse -Filter "*agy*.exe" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
}

# Дедупликация и фильтрация
$uniqueAgy = @()
$seenAgy = @{}
foreach ($cand in $rawAgyCandidates) {
    if ($cand -and (Test-Path $cand -PathType Leaf)) {
        $real = (Resolve-Path $cand).Path
        $key = $real.ToLower()
        if (-not $seenAgy.ContainsKey($key)) {
            $seenAgy[$key] = $true
            if ($real -notlike "*.bak" -and $real -notlike "*.agybak" -and $real -notlike "*.tmp") {
                $uniqueAgy += $real
            }
        }
    }
}

# Сортировка: сначала крупные бинарники движка (>= 10 MB), затем лаунчеры
$sortedAgy = $uniqueAgy | Sort-Object { (Get-Item $_).Length } -Descending

$patchedAny = $false
$wrapperCandidate = $null

foreach ($target in $sortedAgy) {
    $fInfo = Get-Item $target
    $szMB = [math]::Round($fInfo.Length / 1MB, 2)
    Log-Message "Анализ файла CLI: $target ($szMB MB)" -Level "INFO" -Color Cyan

    # Пробуем применить каждую сигнатуру
    $targetPatched = $false
    foreach ($gate in $gateDefinitions) {
        $res = Patch-BinaryGate -FilePath $target -ComponentTitle "Antigravity CLI" `
            -UnpatchedPattern $gate.Unpatched -PatchedPattern $gate.Patched `
            -ReplacementBytes $gate.Fix -Offset $gate.Offset -GateDesc $gate.Desc

        if ($res -eq "patched" -or $res -eq "already_patched") {
            $targetPatched = $true
            $patchedAny = $true
            if ($res -eq "patched") {
                $Summary["Antigravity CLI (agy)"] = "Успешно пропатчен ($($gate.Desc))"
            } elseif ($Summary["Antigravity CLI (agy)"] -ne "Успешно пропатчен") {
                $Summary["Antigravity CLI (agy)"] = "Уже был пропатчен ($($gate.Desc))"
            }
            break
        }
    }

    if (-not $targetPatched) {
        if ($fInfo.Length -lt 10MB) {
            $wrapperCandidate = $target
        }
    }
}

if (-not $patchedAny) {
    if ($wrapperCandidate) {
        Log-Message "========================================================" -Level "HEADER" -Color Yellow
        Log-Message "ВНИМАНИЕ: Обнаружен только загрузчик agy-wrapper:" -Level "WARN" -Color Yellow
        Log-Message "  Файл: $wrapperCandidate ($([math]::Round((Get-Item $wrapperCandidate).Length / 1MB, 2)) MB)" -Level "INFO"
        Log-Message "Движок Antigravity CLI еще не скачан в versions/." -Level "WARN" -Color Yellow
        Write-Host ""
        Log-Message "ПОЧЕМУ AGY ПРОСИТ СКАЧАТЬ ДВИЖОК:" -Level "INFO" -Color White
        Log-Message "  agy-wrapper — это компактный загрузчик от Google. При запуске 'agy' он обращается" -Level "INFO"
        Log-Message "  к серверам Google для загрузки основного исполняемого движка (30-50 МБ)." -Level "INFO"
        Log-Message "  В РФ сервера Google заблокированы провайдерами, поэтому без VPN загрузка не проходит!" -Level "WARN" -Color Yellow
        Write-Host ""
        Log-Message "ЧТО СДЕЛАТЬ ДЛЯ АКТИВАЦИИ CLI:" -Level "HEADER" -Color Green
        Log-Message "  1. Включите VPN (Amnezia / Outline / V2Ray / ByeDPI) для всего ПК." -Level "SUCCESS"
        Log-Message "  2. Откройте командную строку (cmd) и введите: agy" -Level "SUCCESS"
        Log-Message "  3. Дождитесь, пока wrapper скачает движок в versions/." -Level "SUCCESS"
        Log-Message "  4. Запустите patch.bat снова — патчер сразу снимет проверку лицензии!" -Level "SUCCESS"
        Log-Message "  (Если движок уже есть на диске D: перетащите его прямо на patch.bat)" -Level "INFO"
        Log-Message "========================================================" -Level "HEADER" -Color Yellow

        $Summary["Antigravity CLI (agy)"] = "Требуется загрузка движка через VPN"
    } else {
        Log-Message "Antigravity CLI (agy.exe) не обнаружен." -Level "INFO"
    }
}
Write-Host ""

# ---------------------------------------------------------------------------
# 5. ПОИСК И ПАТЧ: VS CODE EXTENSION (extension.js)
# ---------------------------------------------------------------------------
Log-Message "--- Проверка Google Antigravity расширения для VS Code ---" -Level "HEADER" -Color Yellow

$vscodeExtDir = Join-Path $env:USERPROFILE ".vscode\extensions"
$vscodeTarget = $null
if (Test-Path $vscodeExtDir) {
    $matches = Get-ChildItem -Path $vscodeExtDir -Directory -Filter "google.google-antigravity-*" -ErrorAction SilentlyContinue
    foreach ($m in $matches) {
        $p = Join-Path $m.FullName "out\extension.js"
        if (Test-Path $p -PathType Leaf) {
            $vscodeTarget = $p
            break
        }
    }
}

if ($vscodeTarget) {
    Log-Message "Найдено расширение VS Code: $vscodeTarget" -Level "INFO" -Color Cyan
    $extContent = [System.IO.File]::ReadAllText($vscodeTarget, [System.Text.Encoding]::UTF8)

    $injectCode = "{const __primary=options.targetPathOverride||getInstalledTargetPath();const __candidates=[__primary,(0,path_1.join)((0,path_1.dirname)(__primary),'antigravity'+((0,path_1.extname)(__primary)||''))];for(const __p of __candidates){if(__p&&await pathExists(__p)){outputChannel.appendLine('[INSTALL] Existing binary found at '+__p+'. Skipping version check and re-download.');return __p;}}}"
    $part1Regex = [regex]'(outputChannel\s*\.\s*appendLine\s*\(\s*[''"]\[INSTALL\]\s*Checking Antigravity releases[^''"]*[''"]\s*\)\s*;?)'
    $part2Regex = [regex]'const\s+isChannelChanged\s*=\s*manifestFetched\s*&&\s*lastInstalledUrl\s*!==\s*releaseBaseUrl\s*;'

    $isPatched = $extContent.Contains($injectCode) -and $extContent.Contains("const isChannelChanged = false;")
    if ($isPatched) {
        Log-Message "Расширение VS Code уже пропатчено!" -Level "SUCCESS"
        $Summary["VS Code Extension"] = "Уже было пропатчено"
    } else {
        $bak = "$vscodeTarget.bak"
        if (-not (Test-Path $bak)) { Copy-Item -Path $vscodeTarget -Destination $bak -Force }

        $newExt = $extContent
        if (-not $newExt.Contains($injectCode) -and $part1Regex.IsMatch($newExt)) {
            $newExt = $part1Regex.Replace($newExt, '${1}' + $injectCode)
        }
        if ($part2Regex.IsMatch($newExt)) {
            $newExt = $part2Regex.Replace($newExt, 'const isChannelChanged = false;')
        }
        [System.IO.File]::WriteAllText($vscodeTarget, $newExt, [System.Text.Encoding]::UTF8)
        Log-Message "Расширение VS Code успешно пропатчено!" -Level "SUCCESS"
        $Summary["VS Code Extension"] = "Успешно пропатчено"
    }
} else {
    Log-Message "Расширение Google Antigravity для VS Code не обнаружено." -Level "INFO"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 6. ИТОГОВЫЙ ОТЧЕТ
# ---------------------------------------------------------------------------
Log-Message "========================================================" -Level "HEADER" -Color Green
Log-Message "   ИТОГИ ПАТЧИНГА АНТИГРАВИТИ:                          " -Level "HEADER" -Color Green
Log-Message "========================================================" -Level "HEADER" -Color Green

$anySuccess = $false
foreach ($k in $Summary.Keys) {
    $v = $Summary[$k]
    if ($v -like "*Успешно*" -or $v -like "*Уже был*") {
        Log-Message "$k : $v" -Level "SUCCESS"
        $anySuccess = $true
    } elseif ($v -eq "Не найдено") {
        Log-Message "$k : Не установлено на этом ПК (пропущено)" -Level "INFO"
    } else {
        Log-Message "$k : $v" -Level "WARN"
    }
}

Write-Host ""
if ($anySuccess) {
    Log-Message "Все найденные версии Antigravity активированы!" -Level "SUCCESS"
    Log-Message "Можно запускать приложение и авторизоваться." -Level "SUCCESS"
} else {
    Log-Message "Ни один компонент Antigravity не был найден автоматически." -Level "WARN"
    Log-Message "Убедитесь, что Antigravity установлено, или запустите скрипт из папки с программой." -Level "WARN"
}

Log-Message "Подробный лог сохранен в: $LogFile" -Level "INFO"
Write-Host ""
