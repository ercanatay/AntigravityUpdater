# Antigravity Tools Updater - Windows Version
# Supports Windows 10/11 64-bit (including Bootcamp)
# Supports 51 languages with automatic system language detection

param(
    [switch]$Lang,
    [switch]$ResetLang,
    [string]$SetLang = ""
)

# Ensure UTF-8 output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Settings
$REPO_OWNER = "lbjlaq"
$REPO_NAME = "Antigravity-Manager"
$APP_NAME = "Antigravity Tools"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOCALES_DIR = Join-Path $SCRIPT_DIR "locales"
$LANG_PREF_FILE = Join-Path $env:APPDATA "antigravity_updater_lang.txt"
$TEMP_DIR = Join-Path $env:TEMP "AntigravityUpdater"

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
$script:LANG_NAME = "English"
$script:LANG_CODE = "en"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Load-Language {
    param([string]$LangCode)

    $langFile = Join-Path $LOCALES_DIR "$LangCode.ps1"

    if (Test-Path $langFile) {
        . $langFile
        return $true
    } else {
        # Fallback to English
        $enFile = Join-Path $LOCALES_DIR "en.ps1"
        if (Test-Path $enFile) {
            . $enFile
            return $true
        }
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

function Find-InstalledApp {
    foreach ($path in $INSTALL_PATHS) {
        $exePath = Join-Path $path "Antigravity Tools.exe"
        if (Test-Path $exePath) {
            return $path
        }
    }
    return $null
}

function Get-InstalledVersion {
    param([string]$AppPath)

    if (-not $AppPath) { return $null }

    $exePath = Join-Path $AppPath "Antigravity Tools.exe"
    if (Test-Path $exePath) {
        try {
            $version = (Get-Item $exePath).VersionInfo.ProductVersion
            if ($version) { return $version }
            $version = (Get-Item $exePath).VersionInfo.FileVersion
            if ($version) { return $version }
        } catch {}
    }

    # Try version file
    $versionFile = Join-Path $AppPath "version.txt"
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }

    return $null
}

function Stop-AntigravityApp {
    $processes = Get-Process -Name "Antigravity*" -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
}

# Main execution
if ($ResetLang) {
    if (Test-Path $LANG_PREF_FILE) {
        Remove-Item $LANG_PREF_FILE -Force
    }
    Show-LanguageMenu
} elseif ($Lang -or $SetLang) {
    if ($SetLang -and $LANG_CODES -contains $SetLang) {
        $SetLang | Out-File -FilePath $LANG_PREF_FILE -Encoding UTF8 -NoNewline
        Load-Language $SetLang
    } else {
        Show-LanguageMenu
    }
} elseif (-not (Get-SavedLanguage)) {
    Show-LanguageMenu
}

Clear-Host

# Architecture detection
$ARCH = "x64"
$ARCH_NAME = "Windows 64-bit"

# Display header
Write-ColorOutput "`n========================================================" "Cyan"
Write-ColorOutput "         $script:MSG_TITLE" "Cyan"
Write-ColorOutput "========================================================`n" "Cyan"

Write-ColorOutput "   $script:LANG_NAME (use -Lang to change)`n" "Magenta"

# Check current version
Write-ColorOutput "$script:MSG_CHECKING_VERSION" "Blue"
$APP_PATH = Find-InstalledApp
if ($APP_PATH) {
    $CURRENT_VERSION = Get-InstalledVersion $APP_PATH
    if (-not $CURRENT_VERSION) { $CURRENT_VERSION = $script:MSG_UNKNOWN }
    Write-ColorOutput "   $($script:MSG_CURRENT): $CURRENT_VERSION" "Green"
} else {
    $CURRENT_VERSION = $script:MSG_NOT_INSTALLED
    Write-ColorOutput "   $($script:MSG_CURRENT): $CURRENT_VERSION" "Yellow"
}

# Get latest version from GitHub
Write-ColorOutput "$script:MSG_CHECKING_LATEST" "Blue"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $releaseUrl = "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
    $releaseInfo = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing
} catch {
    Write-ColorOutput "$script:MSG_API_ERROR" "Red"
    Write-ColorOutput "Error: $_" "Red"
    Read-Host "Press Enter to exit"
    exit 1
}

$LATEST_VERSION = $releaseInfo.tag_name -replace '^v', ''
Write-ColorOutput "   $($script:MSG_LATEST): $LATEST_VERSION" "Green"
Write-ColorOutput "   $($script:MSG_ARCH): $ARCH_NAME ($ARCH)" "Cyan"

# Check if update is needed
if ($CURRENT_VERSION -eq $LATEST_VERSION) {
    Write-Host ""
    Write-ColorOutput "$script:MSG_ALREADY_LATEST" "Green"
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host ""
Write-ColorOutput "$script:MSG_NEW_VERSION" "Yellow"

# Find Windows download asset
$windowsAsset = $releaseInfo.assets | Where-Object {
    $_.name -match "windows" -or $_.name -match "win" -or $_.name -match "x64.*\.zip" -or $_.name -match "\.msi$" -or $_.name -match "\.exe$"
} | Select-Object -First 1

if (-not $windowsAsset) {
    # Try to find any zip or msi
    $windowsAsset = $releaseInfo.assets | Where-Object {
        $_.name -match "\.zip$" -or $_.name -match "\.msi$"
    } | Select-Object -First 1
}

if (-not $windowsAsset) {
    Write-ColorOutput "No Windows download found in release" "Red"
    Read-Host "Press Enter to exit"
    exit 1
}

$DOWNLOAD_URL = $windowsAsset.browser_download_url
$DOWNLOAD_NAME = $windowsAsset.name

# Create temp directory
if (-not (Test-Path $TEMP_DIR)) {
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
}

$DOWNLOAD_PATH = Join-Path $TEMP_DIR $DOWNLOAD_NAME

# Download
Write-ColorOutput "$script:MSG_DOWNLOADING" "Blue"
Write-Host "   $DOWNLOAD_URL"

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $DOWNLOAD_PATH -UseBasicParsing
    $ProgressPreference = 'Continue'
} catch {
    Write-ColorOutput "$script:MSG_DOWNLOAD_FAILED" "Red"
    Write-ColorOutput "Error: $_" "Red"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-ColorOutput "$script:MSG_DOWNLOAD_COMPLETE" "Green"

# Close running application
Write-ColorOutput "$script:MSG_CLOSING_APP" "Blue"
Stop-AntigravityApp

# Handle installation based on file type
$fileExt = [System.IO.Path]::GetExtension($DOWNLOAD_NAME).ToLower()

if ($fileExt -eq ".msi") {
    Write-ColorOutput "$script:MSG_COPYING_NEW" "Blue"
    $msiArgs = "/i `"$DOWNLOAD_PATH`" /quiet /norestart"
    Start-Process msiexec.exe -ArgumentList $msiArgs -Wait
} elseif ($fileExt -eq ".exe") {
    Write-ColorOutput "$script:MSG_COPYING_NEW" "Blue"
    Start-Process -FilePath $DOWNLOAD_PATH -ArgumentList "/S" -Wait
} elseif ($fileExt -eq ".zip") {
    Write-ColorOutput "$script:MSG_EXTRACTING" "Blue"
    $extractPath = Join-Path $TEMP_DIR "extracted"

    try {
        Expand-Archive -Path $DOWNLOAD_PATH -DestinationPath $extractPath -Force
    } catch {
        Write-ColorOutput "$script:MSG_EXTRACT_FAILED" "Red"
        Read-Host "Press Enter to exit"
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
    } else {
        Write-ColorOutput "$script:MSG_APP_NOT_FOUND" "Red"
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Cleanup
Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue

# Success message
Write-Host ""
Write-ColorOutput "========================================================" "Green"
Write-ColorOutput "         $script:MSG_UPDATE_SUCCESS" "Green"
Write-ColorOutput "========================================================" "Green"
Write-Host ""
Write-ColorOutput "   $($script:MSG_OLD_VERSION): $CURRENT_VERSION" "Yellow"
Write-ColorOutput "   $($script:MSG_NEW_VERSION_LABEL): $LATEST_VERSION" "Green"
Write-Host ""

Read-Host "Press Enter to exit"
