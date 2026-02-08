# Antigravity Tools Updater

Unofficial update scripts for [Antigravity Tools](https://github.com/lbjlaq/Antigravity-Manager) that run on macOS, Windows, Linux, and Docker.

> This repository **does not include the Antigravity Tools application**. It only includes updater tools.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Docker-blue)
![Updater Release](https://img.shields.io/badge/updater-1.5.0-green)
![Languages](https://img.shields.io/badge/languages-51-orange)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

## Table of Contents

- [What Does It Do?](#what-does-it-do)
- [Versions and Releases](#versions-and-releases)
- [Which Updater Should I Use?](#which-updater-should-i-use)
- [Feature Matrix](#feature-matrix)
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Command Reference](#command-reference)
- [Common Scenarios](#common-scenarios)
- [Language Support (51 Languages)](#language-support-51-languages)
- [Log Files](#log-files)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)
- [Repository Structure](#repository-structure)
- [Contributing](#contributing)
- [License](#license)

## What Does It Do?

The updaters in this repository:

1. Check the latest version in the `lbjlaq/Antigravity-Manager` repository.
2. Compare it with the currently installed version.
3. Download and update it in a platform-appropriate way.

## Versions and Releases

- This repository's updater releases: https://github.com/ercanatay/AntigravityUpdater/releases
- Main app (upstream) releases: https://github.com/lbjlaq/Antigravity-Manager/releases

> **Note:** Merging a PR only updates the code. To publish a downloadable updater version, you must also create a GitHub Release with a `vX.Y.Z` tag.

## Which Updater Should I Use?

| Target | Command | What It Updates |
|---|---|---|
| macOS app installation | `./antigravity-update.sh` | `/Applications/Antigravity Tools.app` |
| Windows app installation | `./windows/antigravity-update.ps1` (or `./windows/AntigravityUpdater.bat`) | Local Antigravity Tools installation |
| Linux app installation | `./linux/antigravity-update.sh` | `.deb`, `.rpm`, or `.AppImage` installation |
| Docker deployment | `./docker/antigravity-docker-update.sh` | Docker image/tag update and optional container recreation |

## Feature Matrix

| Feature | macOS | Windows | Linux | Docker |
|---|---|---|---|---|
| 51-language interface | ✅ | ✅ | ✅ | ✅ |
| Automatic language detection | ✅ | ✅ | ✅ | ✅ |
| Check-only mode | ✅ | ✅ | ✅ | ✅ |
| Proxy support | ✅ | ✅ | ✅ | ✅ |
| Silent mode | ✅ | ✅ | ✅ | ✅ |
| Changelog display | ✅ | ✅ | ✅ | ✅ |
| Automatic update scheduling (opt-in) | ✅ | ✅ | ✅ | ✅ |
| User-selectable schedule frequency | ✅ | ✅ | ✅ | ✅ |
| Pre-update backup | ✅ | ✅ | ❌ | ❌ |
| Rollback | ✅ | ✅ | ❌ | ❌ |
| Package type selection | ❌ | ❌ | ✅ | ❌ |
| Restart running process | App reopens | App reopens | Process is terminated | Optional container recreate |

## Quick Start

### macOS

```bash
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater
chmod +x antigravity-update.sh
./antigravity-update.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater\windows
powershell -ExecutionPolicy Bypass -File .\antigravity-update.ps1
```

Alternative launcher:

```powershell
.\AntigravityUpdater.bat
```

### Linux

```bash
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater/linux
chmod +x antigravity-update.sh
./antigravity-update.sh
```

### Docker

```bash
git clone https://github.com/ercanatay/AntigravityUpdater.git
cd AntigravityUpdater
chmod +x docker/antigravity-docker-update.sh
./docker/antigravity-docker-update.sh --check-only
```

## Requirements

### macOS

- macOS 10.15+
- `curl`
- `python3` for update checks
- Write permission under `/Applications`

### Windows

- Windows 10/11 (64-bit)
- PowerShell 5.1+
- Internet access

### Linux

- Bash
- `curl`
- `python3`
- For installation:
  - `.deb`: `apt-get`/`dpkg`
  - `.rpm`: `dnf`, `yum`, `zypper`, or `rpm`
  - `.AppImage`: no package manager required

### Docker updater

- `curl`
- `python3`
- Docker CLI (required for pull/restart)

> Using `--check-only`, you can still see the latest target image info even if Docker is not installed.

## Command Reference

### macOS: `antigravity-update.sh`

```text
--lang, -l          Select language
--reset-lang        Reset saved language preference
--check-only        Only check for updates
--changelog         Show release notes before update
--rollback          Roll back from the latest backup
--silent            Minimize interaction
--no-backup         Skip creating a backup before update
--proxy URL         Use HTTP(S) proxy
--enable-auto-update Enable automatic update checks
--disable-auto-update Disable automatic update checks
--auto-update-frequency VALUE
                    hourly | every3hours | every6hours | daily | weekly | monthly
--help, -h          Show help
```

### Windows: `windows/antigravity-update.ps1`

```text
-Lang               Select language
-ResetLang          Reset saved language preference
-SetLang <code>     Set language directly (e.g., tr, en, de)
-CheckOnly          Only check for updates
-ShowChangelog      Show release notes before update
-Rollback           Roll back from the latest backup
-Silent             Minimize interaction
-NoBackup           Skip creating a backup before update
-ProxyUrl <url>     Use proxy
-EnableAutoUpdate   Enable automatic update checks
-DisableAutoUpdate  Disable automatic update checks
-AutoUpdateFrequency <value>
                    hourly | every3hours | every6hours | daily | weekly | monthly
-Help               Show help
```

### Linux: `linux/antigravity-update.sh`

```text
--lang, -l          Select language
--reset-lang        Reset saved language preference
--check-only        Only check for updates
--changelog         Show release notes before update
--silent            Minimize interaction
--proxy URL         Use HTTP(S) proxy
--format TYPE       auto | deb | rpm | appimage
--enable-auto-update Enable automatic update checks
--disable-auto-update Disable automatic update checks
--auto-update-frequency VALUE
                    hourly | every3hours | every6hours | daily | weekly | monthly
--help, -h          Show help
```

### Docker: `docker/antigravity-docker-update.sh`

```text
--lang, -l                   Select language
--reset-lang                 Reset saved language preference
--check-only                 Only status/update check
--changelog                  Show release notes before pulling image
--restart-container          Recreate current container with the new image
--container-name NAME        Container name (default: antigravity-manager)
--image REPO                 Docker image repository (default: lbjlaq/antigravity-manager)
--tag TAG                    Set target tag manually (default: latest release tag)
--proxy URL                  Proxy for GitHub API requests
--silent                     Minimize interaction
--enable-auto-update         Enable automatic update checks
--disable-auto-update        Disable automatic update checks
--auto-update-frequency VALUE
                            hourly | every3hours | every6hours | daily | weekly | monthly
--help, -h                   Show help
```



### Automatic Update Scheduling (English)

All platform updaters now support optional automatic update checks. You can enable or disable this behavior and choose frequency:

- `hourly`
- `every3hours`
- `every6hours`
- `daily`
- `weekly`
- `monthly`

Examples:

```bash
./antigravity-update.sh --enable-auto-update --auto-update-frequency weekly
./linux/antigravity-update.sh --enable-auto-update --auto-update-frequency daily
./docker/antigravity-docker-update.sh --enable-auto-update --auto-update-frequency every6hours
```

```powershell
.\antigravity-update.ps1 -EnableAutoUpdate -AutoUpdateFrequency monthly
```

## Common Scenarios

### Check only on all platforms

```bash
./antigravity-update.sh --check-only
./linux/antigravity-update.sh --check-only
./docker/antigravity-docker-update.sh --check-only
```

```powershell
.\windows\antigravity-update.ps1 -CheckOnly
```

### Force package type on Linux

```bash
./linux/antigravity-update.sh --format deb
./linux/antigravity-update.sh --format rpm
./linux/antigravity-update.sh --format appimage
```

### Change language

```bash
./antigravity-update.sh --lang
./linux/antigravity-update.sh --lang
./docker/antigravity-docker-update.sh --lang
```

```powershell
.\windows\antigravity-update.ps1 -Lang
.\windows\antigravity-update.ps1 -SetLang tr
```

### Update Docker image + restart container

```bash
./docker/antigravity-docker-update.sh --restart-container --container-name antigravity-manager
```

## Language Support (51 Languages)

Supported language codes:

`en, tr, de, fr, es, it, pt, ru, zh, zh-TW, ja, ko, ar, nl, pl, sv, no, da, fi, uk, cs, hi, el, he, th, vi, id, ms, hu, ro, bg, hr, sr, sk, sl, lt, lv, et, ca, eu, gl, is, fa, sw, af, fil, bn, ta, ur, mi, cy`

Language preference files:

- macOS: `~/.antigravity_updater_lang`
- Windows: `%APPDATA%\antigravity_updater_lang.txt`
- Linux: `~/.antigravity_updater_lang_linux`
- Docker: `~/.antigravity_updater_lang_docker`

## Log Files

- macOS: `~/Library/Application Support/AntigravityUpdater/updater.log`
- Windows: `%APPDATA%\AntigravityUpdater\updater.log`
- Linux: `$XDG_STATE_HOME/AntigravityUpdater/updater.log` (fallback: `~/.local/state/AntigravityUpdater/updater.log`)
- Docker: `$XDG_STATE_HOME/AntigravityUpdater/docker-updater.log` (fallback: `~/.local/state/AntigravityUpdater/docker-updater.log`)

## Troubleshooting

### 1) GitHub API rate limit

For unauthenticated GitHub API usage, the limit is low (usually 60 requests per hour per IP).
Wait a while and try again.

### 2) Permission error during Linux installation

Run with a `sudo`-capable user for `.deb` / `.rpm` installation.

### 3) Linux package manager not found

Use AppImage mode:

```bash
./linux/antigravity-update.sh --format appimage
```

### 4) Docker deployment is managed with Compose

The `--restart-container` option is mainly for containers started with `docker run`.
For Compose, run the following in the relevant directory:

```bash
docker compose pull
docker compose up -d
```

### 5) Windows execution policy blocks the script

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\antigravity-update.ps1
```

### 6) Permission error on macOS

```bash
chmod +x antigravity-update.sh
```

## Security Notes

The current version includes security hardening, especially on macOS:

- Code-signature verification for the source app inside the DMG before installation
- Expected `CFBundleIdentifier` validation
- Symlink source app rejection
- Safer copy/restore using `ditto` instead of `cp -R`
- Additional hardening for temporary file and log handling

For detailed security history, see `CHANGELOG.md`.

## Repository Structure

```text
AntigravityUpdater/
├── antigravity-update.sh                # macOS updater
├── locales/                             # Shared locale files (.sh)
├── windows/
│   ├── antigravity-update.ps1           # Windows updater
│   ├── AntigravityUpdater.bat           # Windows launcher
│   └── locales/                         # Windows locale files (.ps1)
├── linux/
│   └── antigravity-update.sh            # Linux updater
├── docker/
│   └── antigravity-docker-update.sh     # Docker updater
├── CHANGELOG.md
└── README.md
```

## Contributing

- You can open issues or PRs for bug fixes and improvements.
- For translation contributions, keep key names consistent when editing locale files.

## License

MIT. See the `LICENSE` file for details.
