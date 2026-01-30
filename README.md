# Antigravity Tools Updater

A lightweight, multi-language application that automatically updates [Antigravity Tools](https://github.com/lbjlaq/Antigravity-Manager) to the latest version with a single click.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-blue)
![Languages](https://img.shields.io/badge/languages-51-green)
![License](https://img.shields.io/badge/license-MIT-brightgreen)
![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel%20%7C%20x64-orange)

## Features

- **One-Click Update**: Automatically downloads and installs the latest version
- **Multi-Language Support**: 51 languages with automatic system language detection
- **Cross-Platform**: Supports macOS and Windows
- **Universal Binary (macOS)**: Supports both Apple Silicon (M1/M2/M3) and Intel Macs
- **Windows 10/11 (64-bit)**: Full support including Bootcamp installations
- **Smart Detection**: Compares installed version with latest GitHub release
- **Safe Installation**: Removes macOS quarantine flags automatically
- **Persistent Preferences**: Remembers your language choice

## Supported Languages (51)

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
| 한국어 | `ko` | Euskara | `eu` | | |
| العربية | `ar` | Ελληνικά | `el` | | |
| Nederlands | `nl` | עברית | `he` | | |
| Polski | `pl` | ไทย | `th` | | |
| Svenska | `sv` | Tiếng Việt | `vi` | | |
| Norsk | `no` | Bahasa Indonesia | `id` | | |
| Dansk | `da` | Bahasa Melayu | `ms` | | |
| Suomi | `fi` | हिन्दी | `hi` | | |
| Українська | `uk` | Čeština | `cs` | | |

## Installation

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

#### Option 1: Download Installer (Recommended)

1. Download `AntigravityToolsUpdater_x.x.x_x64-setup.exe` from [Releases](../../releases)
2. Run the installer
3. Launch from Start Menu or Desktop shortcut

#### Option 2: Run Script Directly

```powershell
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater/windows
.\AntigravityUpdater.bat
```

Or via PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File antigravity-update.ps1
```

## Usage

### First Run
On first launch, you'll see a language selection menu:

```
╔══════════════════════════════════════════════════════════╗
║     🌍 Select Language / Dil Seçin / 选择语言            ║
╚══════════════════════════════════════════════════════════╝

   1) Türkçe        8) Русский      15) Svenska
   2) English       9) 简体中文      16) Norsk
   3) Deutsch      10) 日本語       17) Dansk
   ...

   0) Auto-detect / Otomatik

➤
```

### Subsequent Runs
The updater remembers your language preference and proceeds directly to update checking.

### Command Line Options

**macOS:**
```bash
# Change language
./antigravity-update.sh --lang
./antigravity-update.sh -l

# Reset language preference
./antigravity-update.sh --reset-lang
```

**Windows:**
```powershell
# Change language
.\antigravity-update.ps1 -Lang

# Reset language preference
.\antigravity-update.ps1 -ResetLang

# Set specific language
.\antigravity-update.ps1 -SetLang tr
```

## How It Works

1. **Version Check**: Reads current installed version from app bundle/executable
2. **GitHub API**: Fetches latest release information
3. **Download**: Downloads appropriate package for your platform/architecture
4. **Install**: Installs the application to the appropriate location
5. **Cleanup**: Removes temporary files (and quarantine flags on macOS)

## Project Structure

```
AntigravityUpdater/
├── Antigravity Updater.app/    # macOS application bundle
├── antigravity-update.sh       # macOS updater script
├── locales/                    # macOS language files
│   ├── en.sh
│   ├── tr.sh
│   └── ...
├── windows/                    # Windows version
│   ├── antigravity-update.ps1  # Windows PowerShell script
│   ├── AntigravityUpdater.bat  # Batch launcher
│   ├── installer.iss           # Inno Setup installer script
│   ├── locales/                # Windows language files
│   │   ├── en.ps1
│   │   ├── tr.ps1
│   │   └── ...
│   └── resources/
├── CHANGELOG.md
├── README.md
└── LICENSE
```

## Requirements

### macOS
- macOS 10.15 (Catalina) or later
- Internet connection
- `/Applications` write permission

### Windows
- Windows 10 or Windows 11 (64-bit)
- PowerShell 5.1 or later (included with Windows)
- Internet connection
- Works on Bootcamp Windows installations

## Troubleshooting

### macOS: "App is damaged and can't be opened"
Run this command to remove quarantine:
```bash
xattr -cr /path/to/Antigravity\ Updater.app
```

### macOS: Permission Denied
Ensure the script is executable:
```bash
chmod +x antigravity-update.sh
```

### Windows: PowerShell Execution Policy
If you see an execution policy error, run:
```powershell
powershell -ExecutionPolicy Bypass -File antigravity-update.ps1
```

### GitHub API Rate Limit
If you see API errors, wait a few minutes and try again. GitHub limits unauthenticated requests.

## Contributing

Contributions are welcome! To add a new language:

### macOS
1. Copy `locales/en.sh` to `locales/[lang-code].sh`
2. Translate all `MSG_*` variables
3. Update `LANG_CODES` and `LANG_NAMES` arrays in main script

### Windows
1. Copy `windows/locales/en.ps1` to `windows/locales/[lang-code].ps1`
2. Translate all `$script:MSG_*` variables

4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Antigravity Tools](https://github.com/lbjlaq/Antigravity-Manager) - The application this updater supports
- All contributors who helped with translations

## Author

**Ercan ATAY**
- GitHub: [@ercanatay](https://github.com/ercanatay)
- Website: [ercanatay.com](https://www.ercanatay.com/en/)

---

Made with ❤️ for the Antigravity Tools community
