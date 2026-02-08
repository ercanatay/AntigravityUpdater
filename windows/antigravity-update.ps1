# Antigravity Tools Updater - Windows Version
# Supports Windows 10/11 64-bit (including Bootcamp)
# Supports 51 languages with automatic system language detection
# Version 1.5.0 - Security Enhanced

param(
    [switch]$Lang,
    [switch]$ResetLang,
    [string]$SetLang = "",
    [switch]$CheckOnly,
    [switch]$ShowChangelog,
    [switch]$Rollback,
    [switch]$Silent,
    [switch]$NoBackup,
    [string]$ProxyUrl = "",
    [switch]$EnableAutoUpdate,
    [switch]$DisableAutoUpdate,
    [ValidateSet("hourly", "every3hours", "every6hours", "daily", "weekly", "monthly")][string]$AutoUpdateFrequency = "",
    [switch]$Help
)

# Ensure UTF-8 output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Version
$UPDATER_VERSION = "1.5.0"

# Settings
$REPO_OWNER = "lbjlaq"
$REPO_NAME = "Antigravity-Manager"
$APP_NAME = "Antigravity Tools"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOCALES_DIR = Join-Path $SCRIPT_DIR "locales"
$LANG_PREF_FILE = Join-Path $env:APPDATA "antigravity_updater_lang.txt"
$LOG_DIR = Join-Path $env:APPDATA "AntigravityUpdater"
$LOG_FILE = Join-Path $LOG_DIR "updater.log"
$BACKUP_DIR = Join-Path $LOG_DIR "backups"

# Secure temp directory with random suffix
$TEMP_DIR = Join-Path $env:TEMP "AntigravityUpdater_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"

# Possible installation paths
$INSTALL_PATHS = @(
    (Join-Path $env:LOCALAPPDATA "Antigravity Tools"),
    (Join-Path ${env:ProgramFiles} "Antigravity Tools"),
    (Join-Path ${env:ProgramFiles(x86)} "Antigravity Tools")
)

# Available languages (51 total)
$LANG_CODES = @("en", "tr", "de", "fr", "es", "it", "pt", "ru", "zh", "zh-TW", "ja", "ko", "ar", "nl", "pl", "sv", "no", "da", "fi", "uk", "cs", "hi", "el", "he", "th", "vi", "id", "ms", "hu", "ro", "bg", "hr", "sr", "sk", "sl", "lt", "lv", "et", "ca", "eu", "gl", "is", "fa", "sw", "af", "fil", "bn", "ta", "ur", "mi", "cy")
$LANG_NAMES = @("English", "Turkce", "Deutsch", "Francais", "Espanol", "Italiano", "Portugues", "Russkiy", "Zhongwen", "Zhongwen-TW", "Nihongo", "Hangugeo", "Arabiya", "Nederlands", "Polski", "Svenska", "Norsk", "Dansk", "Suomi", "Ukrayinska", "Cestina", "Hindi", "Ellinika", "Ivrit", "Thai", "Tieng Viet", "Bahasa Indonesia", "Bahasa Melayu", "Magyar", "Romana", "Balgarski", "Hrvatski", "Srpski", "Slovencina", "Slovenscina", "Lietuviu", "Latviesu", "Eesti", "Catala", "Euskara", "Galego", "Islenska", "Farsi", "Kiswahili", "Afrikaans", "Filipino", "Bangla", "Tamil", "Urdu", "Te Reo Maori", "Cymraeg")

# Initialize message variables with defaults
$script:MSG_TITLE = "Antigravity Tools Updater"
$script:MSG_CHECKING_VERSION = "Checking current version..."
$script:MSG_CURRENT = "Current"
$script:MSG_NOT_INSTALLED = "Not installed"
$script:MSG_UNKNOWN = "Unknown"
$script:MSG_CHECKING_LATEST = "Checking latest version..."
$script:MSG_LATEST = "Latest"
$script:MSG_ARCH = "Architecture"
$script:MSG_ALREADY_LATEST = "You already have the latest version!"
$script:MSG_NEW_VERSION = "New version available! Starting download..."
$script:MSG_DOWNLOADING = "Downloading..."
$script:MSG_DOWNLOAD_FAILED = "Download failed!"
$script:MSG_DOWNLOAD_COMPLETE = "Download complete"
$script:MSG_EXTRACTING = "Extracting..."
$script:MSG_EXTRACT_FAILED = "Extraction failed"
$script:MSG_EXTRACTED = "Extraction complete"
$script:MSG_CLOSING_APP = "Closing current application..."
$script:MSG_REMOVING_OLD = "Removing old version..."
$script:MSG_COPYING_NEW = "Installing new version..."
$script:MSG_APP_NOT_FOUND = "Application not found in archive"
$script:MSG_COPIED = "Application installed"
$script:MSG_UPDATE_SUCCESS = "UPDATE COMPLETED SUCCESSFULLY!"
$script:MSG_OLD_VERSION = "Old version"
$script:MSG_NEW_VERSION_LABEL = "New version"
$script:MSG_API_ERROR = "Cannot access GitHub API"
$script:MSG_SELECT_LANGUAGE = "Select language"
$script:MSG_OPENING_APP = "Opening application..."
$script:MSG_WINDOWS_SUPPORT = "Windows 10/11 64-bit"
$script:MSG_BACKUP_CREATED = "Backup created"
$script:MSG_BACKUP_FAILED = "Backup failed"
$script:MSG_ROLLBACK_SUCCESS = "Rollback successful"
$script:MSG_ROLLBACK_FAILED = "Rollback failed"
$script:MSG_NO_BACKUP = "No backup found"
$script:MSG_HASH_VERIFY = "Verifying file integrity..."
$script:MSG_HASH_FAILED = "File integrity check failed!"
$script:MSG_HASH_OK = "File integrity verified"
$script:MSG_SIGNATURE_CHECK = "Checking digital signature..."
$script:MSG_SIGNATURE_OK = "Digital signature valid"
$script:MSG_SIGNATURE_WARN = "Warning: No valid digital signature"
$script:MSG_AUTO_UPDATE_ENABLED = "Automatic updates enabled"
$script:MSG_AUTO_UPDATE_DISABLED = "Automatic updates disabled"
$script:MSG_AUTO_UPDATE_INVALID_FREQ = "Invalid auto-update frequency"
$script:LANG_NAME = "English"
$script:LANG_CODE = "en"

#region Logging Functions

function Initialize-Logging {
    if (-not (Test-Path $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        Add-Content -Path $LOG_FILE -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}

    # Keep log file under 1MB
    if ((Test-Path $LOG_FILE) -and (Get-Item $LOG_FILE).Length -gt 1MB) {
        $content = Get-Content $LOG_FILE -Tail 1000
        Set-Content -Path $LOG_FILE -Value $content
    }
}

#endregion

#region Security Functions

function Test-SafePath {
    param(
        [string]$Path,
        [string]$BasePath
    )

    try {
        $resolvedPath = [System.IO.Path]::GetFullPath($Path)
        $resolvedBase = [System.IO.Path]::GetFullPath($BasePath)

        if ($resolvedPath -eq $resolvedBase) { return $true }

        $sep = [System.IO.Path]::DirectorySeparatorChar
        $baseWithSep = $resolvedBase.TrimEnd($sep) + $sep
        return $resolvedPath.StartsWith($baseWithSep, [StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Test-ValidLanguageCode {
    param([string]$LangCode)

    # Only allow valid language codes (2 letters or 2-2 format)
    if ($LangCode -notmatch '^[a-z]{2}(-[A-Z]{2})?$') {
        return $false
    }

    return $LANG_CODES -contains $LangCode
}

function Get-FileHashSHA256 {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    try {
        return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
    } catch {
        return $null
    }
}

function Test-FileSignature {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    try {
        $sig = Get-AuthenticodeSignature -FilePath $FilePath -ErrorAction SilentlyContinue
        return ($sig.Status -eq "Valid")
    } catch {
        return $false
    }
}

function Test-DownloadedFile {
    param(
        [string]$FilePath,
        [string]$ExpectedHash = ""
    )

    # Check file exists and has content
    if (-not (Test-Path $FilePath)) {
        Write-Log "Downloaded file not found: $FilePath" "ERROR"
        return $false
    }

    $fileInfo = Get-Item $FilePath
    if ($fileInfo.Length -eq 0) {
        Write-Log "Downloaded file is empty: $FilePath" "ERROR"
        return $false
    }

    # Verify hash if provided
    if ($ExpectedHash) {
        Write-ColorOutput "$script:MSG_HASH_VERIFY" "Blue"
        $actualHash = Get-FileHashSHA256 $FilePath

        if ($actualHash -ne $ExpectedHash) {
            Write-ColorOutput "$script:MSG_HASH_FAILED" "Red"
            Write-Log "Hash mismatch. Expected: $ExpectedHash, Got: $actualHash" "ERROR"
            return $false
        }

        Write-ColorOutput "$script:MSG_HASH_OK" "Green"
        Write-Log "Hash verified: $actualHash" "INFO"
    }

    # Check digital signature for exe/msi
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($ext -in @(".exe", ".msi")) {
        Write-ColorOutput "$script:MSG_SIGNATURE_CHECK" "Blue"

        if (Test-FileSignature $FilePath) {
            Write-ColorOutput "$script:MSG_SIGNATURE_OK" "Green"
            Write-Log "Digital signature valid" "INFO"
        } else {
            Write-ColorOutput "$script:MSG_SIGNATURE_WARN" "Yellow"
            Write-Log "No valid digital signature found" "WARN"
            # Continue anyway but warn user
        }
    }

    return $true
}

#endregion

#region Backup Functions

function New-Backup {
    param([string]$AppPath)

    if (-not $AppPath -or -not (Test-Path $AppPath)) {
        return $null
    }

    try {
        if (-not (Test-Path $BACKUP_DIR)) {
            New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupName = "backup_$timestamp"
        $backupPath = Join-Path $BACKUP_DIR $backupName

        Copy-Item -Path $AppPath -Destination $backupPath -Recurse -Force
        $resolvedPath = [System.IO.Path]::GetFullPath($AppPath)
        $resolvedPath | Out-File -FilePath (Join-Path $backupPath "backup-path.txt") -Encoding UTF8 -NoNewline

        # Keep only last 3 backups
        $backups = Get-ChildItem $BACKUP_DIR -Directory | Sort-Object CreationTime -Descending
        if ($backups.Count -gt 3) {
            $backups | Select-Object -Skip 3 | Remove-Item -Recurse -Force
        }

        Write-Log "Backup created: $backupPath" "INFO"
        return $backupPath
    } catch {
        Write-Log "Backup failed: $_" "ERROR"
        return $null
    }
}

function Restore-Backup {
    $backups = Get-ChildItem $BACKUP_DIR -Directory -ErrorAction SilentlyContinue |
               Sort-Object CreationTime -Descending |
               Select-Object -First 1

    if (-not $backups) {
        Write-ColorOutput "$script:MSG_NO_BACKUP" "Red"
        Write-Log "No backup found for rollback" "ERROR"
        return $false
    }

    try {
        $targetPath = $null
        $metadataPath = Join-Path $backups.FullName "backup-path.txt"

        if (Test-Path $metadataPath) {
            try {
                $savedPath = (Get-Content $metadataPath -Raw).Trim()
                if ($savedPath -and ($INSTALL_PATHS -contains $savedPath)) {
                    $targetPath = $savedPath
                } elseif ($savedPath) {
                    Write-Log "Ignoring backup target outside known install paths: $savedPath" "WARN"
                }
            } catch {
                Write-Log "Failed to read backup metadata: $_" "WARN"
            }
        }

        if (-not $targetPath) {
            $detectedPath = Find-InstalledApp
            if ($detectedPath -and ($INSTALL_PATHS -contains $detectedPath)) {
                $targetPath = $detectedPath
            } else {
                $targetPath = Join-Path $env:LOCALAPPDATA "Antigravity Tools"
            }
        }

        if (Test-Path $targetPath) {
            Remove-Item -Path $targetPath -Recurse -Force
        }

        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
        Get-ChildItem -Path $backups.FullName -Force |
            Where-Object { $_.Name -ne "backup-path.txt" } |
            ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $targetPath -Recurse -Force
            }

        Write-ColorOutput "$script:MSG_ROLLBACK_SUCCESS" "Green"
        Write-Log "Rollback successful from: $($backups.FullName) to: $targetPath" "INFO"
        return $true
    } catch {
        Write-ColorOutput "$script:MSG_ROLLBACK_FAILED" "Red"
        Write-Log "Rollback failed: $_" "ERROR"
        return $false
    }
}

#endregion

#region UI Functions

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Show-Progress {
    param(
        [int]$Percent,
        [string]$Status
    )

    if (-not $Silent) {
        $width = 40
        $filled = [Math]::Floor($width * $Percent / 100)
        $empty = $width - $filled
        $bar = "[" + ("=" * $filled) + (" " * $empty) + "]"
        Write-Host "`r$bar $Percent% $Status" -NoNewline
    }
}

function Remove-TempDirectory {
    if ($TEMP_DIR -and (Test-Path $TEMP_DIR)) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region Language Functions

function Load-Language {
    param([string]$LangCode)

    # Validate language code format
    if (-not (Test-ValidLanguageCode $LangCode)) {
        Write-Log "Invalid language code: $LangCode" "WARN"
        return $false
    }

    $langFile = Join-Path $LOCALES_DIR "$LangCode.ps1"

    # Security: Verify path is within locales directory
    if (-not (Test-SafePath $langFile $LOCALES_DIR)) {
        Write-Log "Path traversal attempt blocked: $langFile" "ERROR"
        return $false
    }

    if (Test-Path $langFile) {
        try {
            . $langFile
            Write-Log "Language loaded: $LangCode" "INFO"
            return $true
        } catch {
            Write-Log "Failed to load language file: $_" "ERROR"
        }
    }

    # Fallback to English
    $enFile = Join-Path $LOCALES_DIR "en.ps1"
    if ((Test-SafePath $enFile $LOCALES_DIR) -and (Test-Path $enFile)) {
        try {
            . $enFile
            return $true
        } catch {}
    }

    return $false
}

function Get-SystemLanguage {
    try {
        $culture = [System.Globalization.CultureInfo]::CurrentUICulture
        $langCode = $culture.TwoLetterISOLanguageName.ToLower()

        # Special handling for Chinese variants
        if ($langCode -eq "zh") {
            if ($culture.Name -like "*TW*" -or $culture.Name -like "*HK*" -or $culture.Name -like "*MO*") {
                $langCode = "zh-TW"
            }
        }

        if ($LANG_CODES -contains $langCode) {
            return $langCode
        }
    } catch {}

    return "en"
}

function Show-LanguageMenu {
    Clear-Host
    Write-ColorOutput "`n========================================================" "Cyan"
    Write-ColorOutput "     Select Language / Dil Secin / Select Language" "Cyan"
    Write-ColorOutput "========================================================`n" "Cyan"

    $cols = 3
    $count = $LANG_CODES.Count
    $rows = [Math]::Ceiling($count / $cols)

    for ($i = 0; $i -lt $rows; $i++) {
        $line = ""
        for ($j = 0; $j -lt $cols; $j++) {
            $idx = $i + ($j * $rows)
            if ($idx -lt $count) {
                $num = $idx + 1
                $name = $LANG_NAMES[$idx]
                $line += "  {0,2}) {1,-15}" -f $num, $name
            }
        }
        Write-Host $line
    }

    Write-Host ""
    Write-ColorOutput "   0) Auto-detect / Otomatik" "Magenta"
    Write-Host ""

    $choice = Read-Host "Select"

    if ($choice -eq "0") {
        $script:SELECTED_LANG = Get-SystemLanguage
    } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $count) {
        $script:SELECTED_LANG = $LANG_CODES[[int]$choice - 1]
    } else {
        $script:SELECTED_LANG = "en"
    }

    # Save preference
    $script:SELECTED_LANG | Out-File -FilePath $LANG_PREF_FILE -Encoding UTF8 -NoNewline

    Load-Language $script:SELECTED_LANG
}

function Get-SavedLanguage {
    if (Test-Path $LANG_PREF_FILE) {
        $savedLang = (Get-Content $LANG_PREF_FILE -Raw).Trim()
        if (Load-Language $savedLang) {
            $script:SELECTED_LANG = $savedLang
            return $true
        }
    }
    return $false
}

function Save-LanguagePreference {
    param([string]$LangCode)
    $LangCode | Out-File -FilePath $LANG_PREF_FILE -Encoding UTF8 -NoNewline
}

#endregion

#region Application Functions

function Find-InstalledApp {
    # Try both naming conventions
    $exeNames = @("antigravity_tools.exe", "Antigravity Tools.exe")
    
    foreach ($path in $INSTALL_PATHS) {
        foreach ($exeName in $exeNames) {
            $exePath = Join-Path $path $exeName
            if (Test-Path $exePath) {
                return $path
            }
        }
    }
    return $null
}

function Get-InstalledVersion {
    param([string]$AppPath)

    if (-not $AppPath) { return $null }

    # Try both naming conventions
    $exeNames = @("antigravity_tools.exe", "Antigravity Tools.exe")
    
    foreach ($exeName in $exeNames) {
        $exePath = Join-Path $AppPath $exeName
        if (Test-Path $exePath) {
            try {
                $version = (Get-Item $exePath).VersionInfo.ProductVersion
                if ($version) { return $version }
                $version = (Get-Item $exePath).VersionInfo.FileVersion
                if ($version) { return $version }
            } catch {}
        }
    }

    # Try version file
    $versionFile = Join-Path $AppPath "version.txt"
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }

    return $null
}

function Stop-AntigravityApp {
    # More precise process matching
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq "Antigravity Tools" -or
        $_.ProcessName -eq "AntigravityTools"
    }

    if ($processes) {
        Write-Log "Stopping processes: $($processes.ProcessName -join ', ')" "INFO"
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
}

function Get-ReleaseInfo {
    param([string]$ProxyUrl = "")

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $releaseUrl = "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"

        $webParams = @{
            Uri = $releaseUrl
            UseBasicParsing = $true
            Headers = @{ "User-Agent" = "AntigravityUpdater/$UPDATER_VERSION" }
        }

        # Proxy support
        if ($ProxyUrl) {
            $webParams.Proxy = $ProxyUrl
            $webParams.ProxyUseDefaultCredentials = $true
            Write-Log "Using proxy: $ProxyUrl" "INFO"
        }

        return Invoke-RestMethod @webParams
    } catch {
        Write-Log "Failed to get release info: $_" "ERROR"
        return $null
    }
}

function Get-WindowsAsset {
    param([object[]]$Assets)

    if (-not $Assets) {
        return $null
    }

    $candidates = @($Assets | Where-Object {
        $_.name -and $_.browser_download_url -and ($_.name -notmatch '(?i)\.sig$')
    })

    if ($candidates.Count -eq 0) {
        return $null
    }

    $platformPattern = '(?i)(^|[._-])(windows|win)([._-]|$)'

    $asset = $candidates | Where-Object {
        $_.name -match '(?i)\.msi$' -and ($_.name -match $platformPattern -or $_.name -match '(?i)x64')
    } | Select-Object -First 1
    if ($asset) { return $asset }

    $asset = $candidates | Where-Object {
        $_.name -match '(?i)\.exe$' -and ($_.name -match $platformPattern -or $_.name -match '(?i)x64')
    } | Select-Object -First 1
    if ($asset) { return $asset }

    $asset = $candidates | Where-Object {
        $_.name -match '(?i)\.zip$' -and ($_.name -match $platformPattern -or $_.name -match '(?i)x64')
    } | Select-Object -First 1
    if ($asset) { return $asset }

    return $candidates |
        Where-Object { $_.name -match '(?i)\.(msi|exe|zip)$' } |
        Sort-Object `
            @{ Expression = { if ($_.name -match '(?i)\.msi$') { 0 } elseif ($_.name -match '(?i)\.exe$') { 1 } else { 2 } } }, `
            @{ Expression = { if ($_.name -match '(?i)x64') { 0 } else { 1 } } } |
        Select-Object -First 1
}

function Show-Changelog {
    param($ReleaseInfo)

    if (-not $ReleaseInfo) {
        Write-ColorOutput "Cannot retrieve changelog" "Red"
        return
    }

    Write-ColorOutput "`n========================================================" "Cyan"
    Write-ColorOutput "   Changelog - v$($ReleaseInfo.tag_name)" "Cyan"
    Write-ColorOutput "========================================================`n" "Cyan"

    if ($ReleaseInfo.body) {
        # Clean markdown formatting for console
        $body = $ReleaseInfo.body -replace '#{1,6}\s*', '' -replace '\*\*', '' -replace '\*', '' -replace '`', ''
        Write-Host $body
    } else {
        Write-Host "No changelog available"
    }

    Write-Host ""
}

function Invoke-Download {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$ProxyUrl = ""
    )

    try {
        $webParams = @{
            Uri = $Url
            OutFile = $OutFile
            UseBasicParsing = $true
        }

        if ($ProxyUrl) {
            $webParams.Proxy = $ProxyUrl
            $webParams.ProxyUseDefaultCredentials = $true
        }

        # Show progress for large files
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest @webParams
        $ProgressPreference = 'Continue'

        return $true
    } catch {
        Write-Log "Download failed: $_" "ERROR"
        return $false
    }
}

#endregion

#region Help Function

function Show-Help {
    Write-Host ""
    Write-Host "Antigravity Tools Updater v$UPDATER_VERSION" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\antigravity-update.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Lang              Change language"
    Write-Host "  -ResetLang         Reset language preference"
    Write-Host "  -SetLang <code>    Set specific language (e.g., tr, en, de)"
    Write-Host "  -CheckOnly         Check for updates only (no install)"
    Write-Host "  -ShowChangelog     Show changelog before update"
    Write-Host "  -Rollback          Rollback to previous version"
    Write-Host "  -Silent            Run without prompts"
    Write-Host "  -NoBackup          Skip automatic backup"
    Write-Host "  -ProxyUrl <url>    Use proxy for connections"
    Write-Host "  -EnableAutoUpdate  Enable automatic update checks"
    Write-Host "  -DisableAutoUpdate Disable automatic update checks"
    Write-Host "  -AutoUpdateFrequency <value> hourly | every3hours | every6hours | daily | weekly | monthly"
    Write-Host "  -Help              Show this help"
    Write-Host ""
}

#endregion

#region Auto Update Configuration

function Get-AutoUpdateMinutes {
    param([string]$Frequency)

    switch ($Frequency) {
        "hourly" { return 60 }
        "every3hours" { return 180 }
        "every6hours" { return 360 }
        "daily" { return 1440 }
        "weekly" { return 10080 }
        "monthly" { return 43200 }
        default { return $null }
    }
}

function Set-AutoUpdateTask {
    param(
        [switch]$Enable,
        [switch]$Disable,
        [string]$Frequency
    )

    $taskName = "AntigravityUpdater-AutoUpdate"

    if ($Disable) {
        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        } catch {}
        Write-ColorOutput $script:MSG_AUTO_UPDATE_DISABLED "Green"
        Write-Log "Automatic updates disabled" "INFO"
        exit 0
    }

    if (-not $Enable) {
        return
    }

    if (-not $Frequency) {
        $Frequency = "daily"
    }

    $minutes = Get-AutoUpdateMinutes -Frequency $Frequency
    if (-not $minutes) {
        Write-ColorOutput "$($script:MSG_AUTO_UPDATE_INVALID_FREQ): $Frequency" "Red"
        exit 1
    }

    $scriptPath = $MyInvocation.MyCommand.Path
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Silent"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes $minutes) -RepetitionDuration ([TimeSpan]::MaxValue)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-ColorOutput "$($script:MSG_AUTO_UPDATE_ENABLED) ($Frequency)" "Green"
    Write-Log "Automatic updates enabled with frequency: $Frequency" "INFO"
    exit 0
}

#endregion

#region Main Execution

# Initialize
Initialize-Logging
Write-Log "=== Updater started v$UPDATER_VERSION ===" "INFO"

# Handle help
if ($Help) {
    Show-Help
    exit 0
}

Set-AutoUpdateTask -Enable:$EnableAutoUpdate -Disable:$DisableAutoUpdate -Frequency:$AutoUpdateFrequency

# Handle rollback
if ($Rollback) {
    Write-Log "Rollback requested" "INFO"
    if (Restore-Backup) {
        if (-not $Silent) { Read-Host "Press Enter to exit" }
        exit 0
    } else {
        if (-not $Silent) { Read-Host "Press Enter to exit" }
        exit 1
    }
}

# Handle language selection
if ($ResetLang -and (Test-Path $LANG_PREF_FILE)) {
    Remove-Item $LANG_PREF_FILE -Force
}

$isValidSetLang = $false
if ($SetLang -and ($LANG_CODES -contains $SetLang)) {
    $isValidSetLang = $true
}

if ($Silent) {
    if ($isValidSetLang -and (Load-Language $SetLang)) {
        $script:SELECTED_LANG = $SetLang
        Save-LanguagePreference $SetLang
    } elseif (-not (Get-SavedLanguage)) {
        $detectedLang = Get-SystemLanguage
        if (Load-Language $detectedLang) {
            $script:SELECTED_LANG = $detectedLang
            Save-LanguagePreference $detectedLang
        } else {
            Load-Language "en" | Out-Null
            $script:SELECTED_LANG = "en"
            Save-LanguagePreference "en"
        }
    }
} else {
    if ($ResetLang) {
        Show-LanguageMenu
    } elseif ($Lang -or $SetLang) {
        if ($isValidSetLang -and (Load-Language $SetLang)) {
            $script:SELECTED_LANG = $SetLang
            Save-LanguagePreference $SetLang
        } else {
            Show-LanguageMenu
        }
    } elseif (-not (Get-SavedLanguage)) {
        Show-LanguageMenu
    }
}

if ($SetLang -and -not $isValidSetLang) {
    Write-Log "Invalid language code requested via -SetLang: $SetLang" "WARN"
    if (-not $Silent) {
        Write-ColorOutput "Invalid language code '$SetLang'." "Yellow"
    }
}

if (-not $Silent) { Clear-Host }

# Architecture detection
$ARCH = "x64"
$ARCH_NAME = "Windows 64-bit"

# Display header
Write-ColorOutput "`n========================================================" "Cyan"
Write-ColorOutput "         $script:MSG_TITLE v$UPDATER_VERSION" "Cyan"
Write-ColorOutput "========================================================`n" "Cyan"

Write-ColorOutput "   $script:LANG_NAME (use -Lang to change)`n" "Magenta"

# Check current version
Write-ColorOutput "$script:MSG_CHECKING_VERSION" "Blue"
$APP_PATH = Find-InstalledApp
if ($APP_PATH) {
    $CURRENT_VERSION = Get-InstalledVersion $APP_PATH
    if (-not $CURRENT_VERSION) { $CURRENT_VERSION = $script:MSG_UNKNOWN }
    Write-ColorOutput "   $($script:MSG_CURRENT): $CURRENT_VERSION" "Green"
    Write-Log "Current version: $CURRENT_VERSION" "INFO"
} else {
    $CURRENT_VERSION = $script:MSG_NOT_INSTALLED
    Write-ColorOutput "   $($script:MSG_CURRENT): $CURRENT_VERSION" "Yellow"
    Write-Log "Application not installed" "INFO"
}

# Get latest version from GitHub
Write-ColorOutput "$script:MSG_CHECKING_LATEST" "Blue"

$releaseInfo = Get-ReleaseInfo -ProxyUrl $ProxyUrl

if (-not $releaseInfo) {
    Write-ColorOutput "$script:MSG_API_ERROR" "Red"
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 1
}

$LATEST_VERSION = $releaseInfo.tag_name -replace '^v', ''
Write-ColorOutput "   $($script:MSG_LATEST): $LATEST_VERSION" "Green"
Write-ColorOutput "   $($script:MSG_ARCH): $ARCH_NAME ($ARCH)" "Cyan"
Write-Log "Latest version: $LATEST_VERSION" "INFO"

# Show changelog if requested
if ($ShowChangelog) {
    Show-Changelog $releaseInfo
    if (-not $Silent) { Read-Host "Press Enter to continue" }
}

# Check if update is needed
$updateNeeded = $false
try {
    $vCurrent = [System.Version]($CURRENT_VERSION -replace '^v','')
    $vLatest = [System.Version]($LATEST_VERSION -replace '^v','')
    if ($vLatest -gt $vCurrent) {
        $updateNeeded = $true
    }
} catch {
    # Fallback to string comparison
    if ($CURRENT_VERSION -ne $LATEST_VERSION) {
        $updateNeeded = $true
    }
}

if (-not $updateNeeded) {
    Write-Host ""
    Write-ColorOutput "$script:MSG_ALREADY_LATEST" "Green"
    Write-Log "Already on latest version (Current: $CURRENT_VERSION, Latest: $LATEST_VERSION)" "INFO"
    Write-Host ""
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 0
}

# Check-only mode
if ($CheckOnly) {
    Write-Host ""
    Write-ColorOutput "Update available: $CURRENT_VERSION -> $LATEST_VERSION" "Yellow"
    Write-Log "Check-only mode: update available" "INFO"
    exit 0
}

Write-Host ""
Write-ColorOutput "$script:MSG_NEW_VERSION" "Yellow"

# Find Windows download asset
$windowsAsset = Get-WindowsAsset -Assets $releaseInfo.assets

if (-not $windowsAsset) {
    Write-ColorOutput "No Windows download found in release" "Red"
    Write-Log "No Windows asset found in release" "ERROR"
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 1
}

$DOWNLOAD_URL = $windowsAsset.browser_download_url
$DOWNLOAD_NAME = $windowsAsset.name
Write-Log "Download URL: $DOWNLOAD_URL" "INFO"

# Create temp directory
if (-not (Test-Path $TEMP_DIR)) {
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
}

$DOWNLOAD_PATH = Join-Path $TEMP_DIR $DOWNLOAD_NAME

# Create backup before update
if (-not $NoBackup -and $APP_PATH) {
    Write-ColorOutput "Creating backup..." "Blue"
    $backupPath = New-Backup $APP_PATH
    if ($backupPath) {
        Write-ColorOutput "   $script:MSG_BACKUP_CREATED" "Green"
    } else {
        Write-ColorOutput "   $script:MSG_BACKUP_FAILED" "Yellow"
    }
}

# Download
Write-ColorOutput "$script:MSG_DOWNLOADING" "Blue"
Write-Host "   $DOWNLOAD_URL"

if (-not (Invoke-Download -Url $DOWNLOAD_URL -OutFile $DOWNLOAD_PATH -ProxyUrl $ProxyUrl)) {
    Write-ColorOutput "$script:MSG_DOWNLOAD_FAILED" "Red"
    Remove-TempDirectory
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 1
}

Write-ColorOutput "$script:MSG_DOWNLOAD_COMPLETE" "Green"

# Verify downloaded file
if (-not (Test-DownloadedFile $DOWNLOAD_PATH)) {
    Write-ColorOutput "File verification failed" "Red"
    Remove-TempDirectory
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 1
}

# Close running application
Write-ColorOutput "$script:MSG_CLOSING_APP" "Blue"
Stop-AntigravityApp

# Handle installation based on file type
$fileExt = [System.IO.Path]::GetExtension($DOWNLOAD_NAME).ToLower()

if ($fileExt -eq ".msi") {
    Write-ColorOutput "$script:MSG_COPYING_NEW" "Blue"
    $msiArgs = "/i `"$DOWNLOAD_PATH`" /quiet /norestart"
    Write-Log "Installing MSI: $msiArgs" "INFO"
    Start-Process msiexec.exe -ArgumentList $msiArgs -Wait
} elseif ($fileExt -eq ".exe") {
    Write-ColorOutput "$script:MSG_COPYING_NEW" "Blue"
    Write-Log "Installing EXE: $DOWNLOAD_PATH" "INFO"
    Start-Process -FilePath $DOWNLOAD_PATH -ArgumentList "/S" -Wait
} elseif ($fileExt -eq ".zip") {
    Write-ColorOutput "$script:MSG_EXTRACTING" "Blue"
    $extractPath = Join-Path $TEMP_DIR "extracted"

    try {
        Expand-Archive -Path $DOWNLOAD_PATH -DestinationPath $extractPath -Force
    } catch {
        Write-ColorOutput "$script:MSG_EXTRACT_FAILED" "Red"
        Write-Log "Extraction failed: $_" "ERROR"
        Remove-TempDirectory
        if (-not $Silent) { Read-Host "Press Enter to exit" }
        exit 1
    }

    Write-ColorOutput "$script:MSG_EXTRACTED" "Green"

    # Remove old version if exists
    if ($APP_PATH -and (Test-Path $APP_PATH)) {
        Write-ColorOutput "$script:MSG_REMOVING_OLD" "Blue"
        Remove-Item -Path $APP_PATH -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Find and copy new version
    Write-ColorOutput "$script:MSG_COPYING_NEW" "Blue"

    $sourceApp = Get-ChildItem -Path $extractPath -Recurse -Filter "*.exe" |
                 Where-Object { $_.Name -like "*Antigravity*" } |
                 Select-Object -First 1

    if (-not $sourceApp) {
        $sourceApp = Get-ChildItem -Path $extractPath -Recurse -Filter "*.exe" | Select-Object -First 1
    }

    if ($sourceApp) {
        $targetPath = Join-Path $env:LOCALAPPDATA "Antigravity Tools"
        if (-not (Test-Path $targetPath)) {
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
        }

        $sourceDir = $sourceApp.DirectoryName
        Copy-Item -Path "$sourceDir\*" -Destination $targetPath -Recurse -Force

        Write-ColorOutput "$script:MSG_COPIED" "Green"
        Write-Log "Application installed to: $targetPath" "INFO"
    } else {
        Write-ColorOutput "$script:MSG_APP_NOT_FOUND" "Red"
        Write-Log "Application not found in archive" "ERROR"
        Remove-TempDirectory
        if (-not $Silent) { Read-Host "Press Enter to exit" }
        exit 1
    }
} else {
    Write-ColorOutput "Unsupported installer file type: $fileExt" "Red"
    Write-Log "Unsupported installer file type: $fileExt ($DOWNLOAD_NAME)" "ERROR"
    Remove-TempDirectory
    if (-not $Silent) { Read-Host "Press Enter to exit" }
    exit 1
}

# Cleanup
Remove-TempDirectory

# Success message
Write-Host ""
Write-ColorOutput "========================================================" "Green"
Write-ColorOutput "         $script:MSG_UPDATE_SUCCESS" "Green"
Write-ColorOutput "========================================================" "Green"
Write-Host ""
Write-ColorOutput "   $($script:MSG_OLD_VERSION): $CURRENT_VERSION" "Yellow"
Write-ColorOutput "   $($script:MSG_NEW_VERSION_LABEL): $LATEST_VERSION" "Green"
Write-Host ""

Write-Log "Update completed: $CURRENT_VERSION -> $LATEST_VERSION" "INFO"

if (-not $Silent) { Read-Host "Press Enter to exit" }

#endregion
