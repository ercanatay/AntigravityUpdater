# Antigravity Tools Updater

Cross-platform updater scripts for [Antigravity Tools](https://github.com/lbjlaq/Antigravity-Manager).

This repository does **not** contain Antigravity Tools itself. It provides updaters that:
- Check the latest release from `lbjlaq/Antigravity-Manager`
- Compare with your installed/current version
- Download and install/update with platform-specific logic

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Docker-blue)
![Updater Release](https://img.shields.io/badge/updater-1.4.2-green)
![Languages](https://img.shields.io/badge/languages-51-orange)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

## Releases

- Updater releases (this repo): https://github.com/ercanatay/AntigravityUpdater/releases
- Antigravity Tools releases (upstream): https://github.com/lbjlaq/Antigravity-Manager/releases

## Which Updater Should You Use?

| Target | Script | What it updates |
|---|---|---|
| macOS app install | `./antigravity-update.sh` | `/Applications/Antigravity Tools.app` |
| Windows app install | `./windows/antigravity-update.ps1` (or `./windows/AntigravityUpdater.bat`) | Local Antigravity Tools installation |
| Linux app install | `./linux/antigravity-update.sh` | `.deb`, `.rpm`, or `.AppImage` installation |
| Docker deployment | `./docker/antigravity-docker-update.sh` | Docker image/tag and optional container recreate |

## Feature Matrix

| Feature | macOS | Windows | Linux | Docker |
|---|---|---|---|---|
| 51-language UI | Yes | Yes | Yes | Yes |
| Auto language detection | Yes | Yes | Yes | Yes |
| Check-only mode | Yes | Yes | Yes | Yes |
| Proxy support | Yes | Yes | Yes | Yes |
| Silent mode | Yes | Yes | Yes | Yes |
| Changelog display | Yes | Yes | Yes | Yes |
| Backup before update | Yes | Yes | No | No |
| Rollback | Yes | Yes | No | No |
| Package-type selection | No | No | Yes | No |
| Restart running service/container | App relaunch | App relaunch | App process stop | Optional container recreate |

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
- Optional for update checks: `python3`
- Write permission for `/Applications`

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
- Docker CLI (required for pull/restart; check-only still runs without Docker and reports latest target image)

## Command Reference

### macOS: `antigravity-update.sh`

```text
--lang, -l          Change language
--reset-lang        Reset language preference
--check-only        Check for updates only
--changelog         Show release notes before update
--rollback          Restore latest backup
--silent            Minimal output
--no-backup         Skip backup creation
--proxy URL         Use HTTP(S) proxy
--help, -h          Show help
```

### Windows: `windows/antigravity-update.ps1`

```text
-Lang               Change language
-ResetLang          Reset language preference
-SetLang <code>     Set language directly (example: tr, en, de)
-CheckOnly          Check for updates only
-ShowChangelog      Show release notes before update
-Rollback           Restore latest backup
-Silent             Minimal output
-NoBackup           Skip backup creation
-ProxyUrl <url>     Use proxy
-Help               Show help
```

### Linux: `linux/antigravity-update.sh`

```text
--lang, -l          Change language
--reset-lang        Reset language preference
--check-only        Check for updates only
--changelog         Show release notes before update
--silent            Minimal output
--proxy URL         Use HTTP(S) proxy
--format TYPE       auto | deb | rpm | appimage
--help, -h          Show help
```

### Docker: `docker/antigravity-docker-update.sh`

```text
--lang, -l                   Change language
--reset-lang                 Reset language preference
--check-only                 Check status only
--changelog                  Show release notes before pull/restart
--restart-container          Recreate existing container with new image
--container-name NAME        Container name (default: antigravity-manager)
--image REPO                 Image repository (default: lbjlaq/antigravity-manager)
--tag TAG                    Override target tag (default: latest upstream release tag)
--proxy URL                  Use HTTP(S) proxy for GitHub API request
--silent                     Minimal output
--help, -h                   Show help
```

## Common Usage Examples

### Check only (all platforms)

```bash
./antigravity-update.sh --check-only
./linux/antigravity-update.sh --check-only
./docker/antigravity-docker-update.sh --check-only
```

```powershell
.\windows\antigravity-update.ps1 -CheckOnly
```

### Force Linux package type

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

### Docker: pull and restart container

```bash
./docker/antigravity-docker-update.sh --restart-container --container-name antigravity-manager
```

## Language Support (51)

Supported language codes:

`en, tr, de, fr, es, it, pt, ru, zh, zh-TW, ja, ko, ar, nl, pl, sv, no, da, fi, uk, cs, hi, el, he, th, vi, id, ms, hu, ro, bg, hr, sr, sk, sl, lt, lv, et, ca, eu, gl, is, fa, sw, af, fil, bn, ta, ur, mi, cy`

Language preference files:

- macOS: `~/.antigravity_updater_lang`
- Windows: `%APPDATA%\antigravity_updater_lang.txt`
- Linux: `~/.antigravity_updater_lang_linux`
- Docker updater: `~/.antigravity_updater_lang_docker`

## Log Files

- macOS: `~/Library/Application Support/AntigravityUpdater/updater.log`
- Windows: `%APPDATA%\AntigravityUpdater\updater.log`
- Linux: `$XDG_STATE_HOME/AntigravityUpdater/updater.log` (fallback: `~/.local/state/AntigravityUpdater/updater.log`)
- Docker updater: `$XDG_STATE_HOME/AntigravityUpdater/docker-updater.log` (fallback: `~/.local/state/AntigravityUpdater/docker-updater.log`)

## Troubleshooting

### GitHub API rate limit

Unauthenticated GitHub API requests are limited (commonly 60 requests/hour per IP).
Wait and retry later if rate-limited.

### Linux install requires privileges

Use a user with `sudo` capability for `.deb`/`.rpm` installation.

### Linux package manager not found

Use AppImage mode:

```bash
./linux/antigravity-update.sh --format appimage
```

### Docker container is compose-managed

`--restart-container` is intended for `docker run` containers.
For compose deployments, run this in your compose directory:

```bash
docker compose pull
docker compose up -d
```

### Windows execution policy blocks script

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\antigravity-update.ps1
```

### macOS permission issue

```bash
chmod +x antigravity-update.sh
```

## Security Notes

Current updaters include hardened locale loading and safer temp/log handling.
Security-related details are tracked in `CHANGELOG.md`.

## Repository Layout

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

- Open an issue or PR for bug fixes and improvements.
- For localization updates, edit the relevant locale files and keep message keys consistent.

## License

MIT. See `LICENSE`.
