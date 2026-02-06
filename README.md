# Antigravity Tools Updater

A lightweight, multi-language, cross-platform application that automatically updates [Antigravity Tools](https://github.com/lbjlaq/Antigravity-Manager) to the latest version with a single click.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-blue)
![Version](https://img.shields.io/badge/version-1.4.1-green)
![Languages](https://img.shields.io/badge/languages-51-orange)
![License](https://img.shields.io/badge/license-MIT-brightgreen)
![Security](https://img.shields.io/badge/security-enhanced-purple)

## ✨ Features

### Core Features
- **One-Click Update**: Automatically downloads and installs the latest version
- **Multi-Language Support**: 51 languages with automatic system language detection (macOS + Windows + Linux + Docker updater)
- **Cross-Platform**: Supports macOS, Windows, and Linux
- **Universal Binary (macOS)**: Supports both Apple Silicon (M1/M2/M3) and Intel Macs
- **Windows 10/11 (64-bit)**: Full support including Bootcamp installations
- **Linux (x86_64 + aarch64)**: Auto-selects `.deb`, `.rpm`, or `.AppImage` assets
- **Linux UX**: Localized output with shared 51-language locale files
- **Docker Deployment Updater**: Pull latest container image and optionally restart existing container

### 🔒 Security Features (v1.2.0)
- **Path Traversal Protection**: Locale files validated to prevent directory traversal attacks
- **Language Code Validation**: Regex-based validation ensures only valid codes accepted
- **Hash Verification**: SHA256 integrity checking for downloaded files
- **Code Signature Check**: Verifies app signatures (codesign on macOS, Authenticode on Windows)
- **Secure Temp Directory**: Random suffix prevents prediction attacks
- **TLS 1.2 Enforced**: All connections use secure protocols

### 💾 Backup & Recovery (v1.2.0)
- **Automatic Backup**: Creates backup before each update
- **Rollback Support**: One-click restore to previous version
- **Backup Rotation**: Keeps last 3 backups automatically

### 📝 Logging (v1.2.0)
- **Comprehensive Logging**: All operations logged with timestamps
- **Log Rotation**: Automatic rotation when file exceeds 1MB
- **Debug Support**: Full operation history for troubleshooting

### 🛠️ Advanced Options (v1.2.0)
- **Check-Only Mode**: Check for updates without installing
- **Silent Mode**: Run without prompts (for automation/scripts)
- **Changelog Display**: View release notes before updating
- **Proxy Support**: Corporate network compatibility

## 🌍 Supported Languages (51)

| Language | Code | Language | Code | Language | Code |
|----------|------|----------|------|----------|------|
| English | `en` | Magyar | `hu` | Galego | `gl` |
| Türkçe | `tr` | Română | `ro` | Íslenska | `is` |
| Deutsch | `de` | Български | `bg` | فارسی | `fa` |
| Français | `fr` | Hrvatski | `hr` | Kiswahili | `sw` |
| Español | `es` | Srpski | `sr` | Afrikaans | `af` |
| Italiano | `it` | Slovenčina | `sk` | Filipino | `fil` |
| Português | `pt` | Slovenščina | `sl` | বাংলা | `bn` |
| Русский | `ru` | Lietuvių | `lt` | தமிழ் | `ta` |
| 简体中文 | `zh` | Latviešu | `lv` | اردو | `ur` |
| 繁體中文 | `zh-TW` | Eesti | `et` | Te Reo Māori | `mi` |
| 日本語 | `ja` | Català | `ca` | Cymraeg | `cy` |
| 한국어 | `ko` | Euskara | `eu` | Suomi | `fi` |
| العربية | `ar` | Ελληνικά | `el` | Українська | `uk` |
| Nederlands | `nl` | עברית | `he` | Čeština | `cs` |
| Polski | `pl` | ไทย | `th` | हिन्दी | `hi` |
| Svenska | `sv` | Tiếng Việt | `vi` | | |
| Norsk | `no` | Bahasa Indonesia | `id` | | |
| Dansk | `da` | Bahasa Melayu | `ms` | | |

## 📥 Installation

### macOS

#### Option 1: Download Release (Recommended)
1. Download the latest `Antigravity.Updater.zip` from [Releases](../../releases)
2. Extract and move `Antigravity Updater.app` to your Applications folder
3. Double-click to run

#### Option 2: Run Script Directly
```bash
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater
chmod +x antigravity-update.sh
./antigravity-update.sh
```

### Windows

#### Option 1: Download Portable (Recommended)
1. Download `AntigravityToolsUpdater_1.2.0_x64-portable.zip` from [Releases](../../releases)
2. Extract to any folder
3. Run `AntigravityUpdater.bat`

#### Option 2: Run Script Directly
```powershell
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater/windows
.\AntigravityUpdater.bat
```

### Linux

#### Option 1: Run Script Directly (Recommended)
```bash
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater/linux
chmod +x antigravity-update.sh
./antigravity-update.sh
```

#### Option 2: Force Package Type
```bash
# Force .deb
./antigravity-update.sh --format deb

# Force .rpm
./antigravity-update.sh --format rpm

# Force AppImage
./antigravity-update.sh --format appimage
```

### Docker

```bash
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater
chmod +x docker/antigravity-docker-update.sh
./docker/antigravity-docker-update.sh --check-only
```

## 💻 Usage

### Basic Usage

On first launch, select your preferred language. The updater remembers your choice for future runs.

### Command Line Options

#### macOS
```bash
# Standard update (with automatic backup)
./antigravity-update.sh

# Change language
./antigravity-update.sh --lang

# Reset language preference
./antigravity-update.sh --reset-lang

# Check for updates only (no install)
./antigravity-update.sh --check-only

# Show changelog before update
./antigravity-update.sh --changelog

# Rollback to previous version
./antigravity-update.sh --rollback

# Silent mode (no prompts, for automation)
./antigravity-update.sh --silent

# Skip automatic backup
./antigravity-update.sh --no-backup

# Use with corporate proxy
./antigravity-update.sh --proxy "http://proxy.company.com:8080"

# Show help
./antigravity-update.sh --help
```

#### Windows
```powershell
# Standard update (with automatic backup)
.\antigravity-update.ps1

# Change language
.\antigravity-update.ps1 -Lang

# Reset language preference
.\antigravity-update.ps1 -ResetLang

# Check for updates only (no install)
.\antigravity-update.ps1 -CheckOnly

# Show changelog before update
.\antigravity-update.ps1 -ShowChangelog

# Rollback to previous version
.\antigravity-update.ps1 -Rollback

# Silent mode (no prompts, for automation)
.\antigravity-update.ps1 -Silent

# Skip automatic backup
.\antigravity-update.ps1 -NoBackup

# Use with corporate proxy
.\antigravity-update.ps1 -ProxyUrl "http://proxy.company.com:8080"
```

#### Linux
```bash
# Standard update
./linux/antigravity-update.sh

# Change language
./linux/antigravity-update.sh --lang

# Reset language preference
./linux/antigravity-update.sh --reset-lang

# Check for updates only (no install)
./linux/antigravity-update.sh --check-only

# Show changelog before update
./linux/antigravity-update.sh --changelog

# Silent mode
./linux/antigravity-update.sh --silent

# Use with corporate proxy
./linux/antigravity-update.sh --proxy "http://proxy.company.com:8080"

# Select package type manually
./linux/antigravity-update.sh --format auto
```

#### Docker
```bash
# Change language
./docker/antigravity-docker-update.sh --lang

# Reset language preference
./docker/antigravity-docker-update.sh --reset-lang

# Check only
./docker/antigravity-docker-update.sh --check-only

# Pull latest image based on latest Antigravity-Manager release
./docker/antigravity-docker-update.sh

# Pull specific Docker tag
./docker/antigravity-docker-update.sh --tag v4.1.7

# Pull and restart existing container
./docker/antigravity-docker-update.sh --restart-container --container-name antigravity-manager
```

## 🔄 How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  1. Version Check    │ Read installed version from app     │
├─────────────────────────────────────────────────────────────┤
│  2. GitHub API       │ Fetch latest release information    │
├─────────────────────────────────────────────────────────────┤
│  3. Backup           │ Create backup of current version    │
├─────────────────────────────────────────────────────────────┤
│  4. Download         │ Download appropriate package         │
├─────────────────────────────────────────────────────────────┤
│  5. Verify           │ Check hash and code signature       │
├─────────────────────────────────────────────────────────────┤
│  6. Install          │ Install to appropriate location     │
├─────────────────────────────────────────────────────────────┤
│  7. Cleanup          │ Remove temp files, quarantine flags │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
AntigravityUpdater/
├── Antigravity Updater.app/    # macOS application bundle
├── antigravity-update.sh       # macOS updater script (v1.2.0)
├── locales/                    # macOS language files (51)
│   ├── en.sh
│   ├── tr.sh
│   └── ...
├── windows/                    # Windows version
│   ├── antigravity-update.ps1  # Windows PowerShell script (v1.2.0)
│   ├── AntigravityUpdater.bat  # Batch launcher
│   ├── installer.iss           # Inno Setup installer script
│   ├── locales/                # Windows language files (51)
│   │   ├── en.ps1
│   │   ├── tr.ps1
│   │   └── ...
│   └── resources/
├── linux/                      # Linux version
│   ├── antigravity-update.sh   # Linux updater script
│   └── README.md
├── docker/                     # Docker updater
│   ├── antigravity-docker-update.sh
│   └── README.md
├── releases/                   # Release packages
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## 📋 Requirements

### macOS
- macOS 10.15 (Catalina) or later
- Apple Silicon (M1/M2/M3) or Intel processor
- Internet connection
- `/Applications` write permission

### Windows
- Windows 10 or Windows 11 (64-bit)
- PowerShell 5.1 or later (included with Windows)
- Internet connection
- Works on Bootcamp Windows installations

### Linux
- Linux distribution with Bash
- `curl` and `python3`
- For package install:
  - `.deb`: `apt-get`/`dpkg`
  - `.rpm`: `dnf`, `yum`, `zypper`, or `rpm`
- Internet connection

### Docker Updater
- Docker CLI
- `curl` and `python3`
- Internet connection to GitHub API and Docker registry

## 📝 Log Files

| Platform | Location |
|----------|----------|
| **macOS** | `~/Library/Application Support/AntigravityUpdater/updater.log` |
| **Windows** | `%APPDATA%\AntigravityUpdater\updater.log` |
| **Linux** | `$XDG_STATE_HOME/AntigravityUpdater/updater.log` (fallback: `~/.local/state/AntigravityUpdater/updater.log`) |
| **Docker Updater** | `$XDG_STATE_HOME/AntigravityUpdater/docker-updater.log` (fallback: `~/.local/state/AntigravityUpdater/docker-updater.log`) |

## 🔧 Troubleshooting

### macOS: "App is damaged and can't be opened"
```bash
xattr -cr /path/to/Antigravity\ Updater.app
```

### macOS: Permission Denied
```bash
chmod +x antigravity-update.sh
```

### Windows: PowerShell Execution Policy
```powershell
powershell -ExecutionPolicy Bypass -File antigravity-update.ps1
```

### Linux: Permission Denied
```bash
chmod +x ./linux/antigravity-update.sh
```

### Linux: No package manager found
Use AppImage mode:
```bash
./linux/antigravity-update.sh --format appimage
```

### Docker: Container is managed by docker compose
Use compose update in your compose directory:
```bash
docker compose pull && docker compose up -d
```

### GitHub API Rate Limit
Wait a few minutes and try again. GitHub limits unauthenticated requests to 60/hour.

### Rollback Not Working
Ensure you have a backup available. Backups are created automatically before each update unless `--no-backup` is used.

---

## 📜 Changelog

### [1.4.0] - 2026-02-06 - Docker Updater

#### Added
- **Docker updater script** at `docker/antigravity-docker-update.sh`
- Docker-specific docs at `docker/README.md`
- `--restart-container` flow for docker-run based containers

#### Changed
- Updated `README.md` with Docker install/usage/requirements/log paths/troubleshooting
- Added 51-language support to Linux and Docker updater flows (`--lang`, `--reset-lang`)

### [1.3.0] - 2026-02-06 - Linux Support

#### Added
- **Linux updater script** at `linux/antigravity-update.sh`
- Automatic Linux package selection based on distro/tooling:
  - `.deb` for Debian/Ubuntu based systems
  - `.rpm` for Fedora/RHEL/openSUSE based systems
  - `.AppImage` fallback for generic Linux environments
- Linux-specific documentation at `linux/README.md`

### [1.2.0] - 2026-01-30 - Security Enhanced

#### 🔒 Security Enhancements
- **Path Traversal Protection**: Locale files validated to prevent directory traversal attacks
- **Language Code Validation**: Regex-based validation (only `xx` or `xx-XX` format accepted)
- **SHA256 Hash Verification**: Support for verifying downloaded file integrity
- **Code Signature Check**:
  - macOS: `codesign --verify --deep --strict`
  - Windows: Authenticode signature validation
- **Secure Temp Directory**: Random suffix added to temp path
- **Comprehensive Logging**: Full operation logging with automatic rotation (max 1MB)

#### 🆕 New Features
| Feature | macOS | Windows |
|---------|-------|---------|
| Automatic Backup | ✅ | ✅ |
| Rollback | `--rollback` | `-Rollback` |
| Check-Only | `--check-only` | `-CheckOnly` |
| Silent Mode | `--silent` | `-Silent` |
| Changelog | `--changelog` | `-ShowChangelog` |
| No Backup | `--no-backup` | `-NoBackup` |
| Proxy Support | `--proxy` | `-ProxyUrl` |
| Help | `--help` | `-Help` |

#### 🔧 Improvements
- More precise process termination (exact name matching)
- Better User-Agent header for GitHub API requests
- Enhanced error handling and user feedback

### [1.1.0] - 2026-01-30 - Windows Support

#### Added
- **Full Windows 10/11 64-bit support**
  - PowerShell-based updater script
  - Batch file launcher for easy execution
  - Inno Setup installer script
  - Works on Bootcamp Windows installations
- Windows-specific locale files (51 languages)
- Separate `windows/` directory structure

### [1.0.0] - 2026-01-15 - Initial Release

#### Added
- macOS application bundle (.app)
- 51 language support with automatic detection
- Universal Binary support (Apple Silicon + Intel)
- One-click update functionality
- Persistent language preferences
- Automatic quarantine flag removal
- GitHub API integration

---

## 🤝 Contributing

Contributions are welcome! To add a new language:

### macOS
1. Copy `locales/en.sh` to `locales/[lang-code].sh`
2. Translate all `MSG_*` variables
3. Update `LANG_CODES` and `LANG_NAMES` arrays in main script

### Windows
1. Copy `windows/locales/en.ps1` to `windows/locales/[lang-code].ps1`
2. Translate all `$script:MSG_*` variables

Then submit a pull request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Antigravity Tools](https://github.com/lbjlaq/Antigravity-Manager) - The application this updater supports
- All contributors who helped with translations

### Special Thanks
- [@nvtptest](https://github.com/nvtptest) - Fixed Windows EXE detection issue ([#1](https://github.com/ercanatay/AntigravityUpdater/pull/1))

## 👤 Author

**Ercan ATAY**
- GitHub: [@ercanatay](https://github.com/ercanatay)
- Website: [ercanatay.com](https://www.ercanatay.com/en/)

---

<p align="center">
Made with ❤️ for the Antigravity Tools community
</p>
