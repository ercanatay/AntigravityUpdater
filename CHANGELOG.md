# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-02-08

### Added
- Added opt-in automatic update scheduling for all updater targets:
  - macOS (`antigravity-update.sh`)
  - Windows (`windows/antigravity-update.ps1`)
  - Linux (`linux/antigravity-update.sh`)
  - Docker (`docker/antigravity-docker-update.sh`)
- Added schedule frequency selection options:
  - `hourly`
  - `every3hours`
  - `every6hours`
  - `daily`
  - `weekly`
  - `monthly`
- Added enable/disable auto-update CLI options to all platform updaters.
- Added new auto-update locale message keys to all shell and PowerShell language files.

### Changed
- Updated `README.md` feature matrix and command reference with automatic update scheduling.
- Bumped updater metadata and badges to `1.5.0`.

## [1.4.3] - 2026-02-07

### Added
- Docker updater: `--changelog` flag to display GitHub release notes before pull/restart ([#5](https://github.com/ercanatay/AntigravityUpdater/pull/5))

### Fixed
- macOS: Add cleanup trap for temp directory to prevent leaks on unexpected exit ([#8](https://github.com/ercanatay/AntigravityUpdater/pull/8))
- macOS: Add `--proxy` argument validation to prevent crash when URL is missing ([#8](https://github.com/ercanatay/AntigravityUpdater/pull/8))
- macOS: Fix `.app` bundle locale path resolution ([#8](https://github.com/ercanatay/AntigravityUpdater/pull/8))
- macOS: Fix unclosed box border characters in terminal UI ([#8](https://github.com/ercanatay/AntigravityUpdater/pull/8))
- Linux: Replace overly broad `pkill -f` with `pkill -x` to prevent killing unrelated processes ([#8](https://github.com/ercanatay/AntigravityUpdater/pull/8))

### Changed
- Optimized JSON parsing in macOS, Linux, and Docker scripts to use a single `python3` invocation instead of two ([#7](https://github.com/ercanatay/AntigravityUpdater/pull/7))

### Security
- macOS: Verify code signature on DMG source app **before** removing the existing installation; failure is now fatal ([#12](https://github.com/ercanatay/AntigravityUpdater/pull/12))
- macOS: Reject symlinked source apps to prevent path traversal ([#12](https://github.com/ercanatay/AntigravityUpdater/pull/12))
- macOS: `verify_codesign()` now checks `CFBundleIdentifier` matches expected bundle ID ([#12](https://github.com/ercanatay/AntigravityUpdater/pull/12))
- macOS: Validate `LATEST_VERSION` format and guard against stale env values ([#12](https://github.com/ercanatay/AntigravityUpdater/pull/12))
- macOS: Replaced `cp -R` with `ditto` for backup, restore, and install operations ([#12](https://github.com/ercanatay/AntigravityUpdater/pull/12))
- Bumped updater metadata and badges to `1.4.3`

## [1.4.2] - 2026-02-06

### Added
- Linux updater now supports the shared 51-language locale set with language selection options:
  - `--lang`
  - `--reset-lang`
- Docker updater now supports the shared 51-language locale set with language selection options:
  - `--lang`
  - `--reset-lang`

### Changed
- Rewrote `README.md` for clearer onboarding, platform guidance, and command reference
- Updated Linux and Docker README files with language option usage examples
- Bumped updater/application metadata and badges to `1.4.2`

## [1.4.1] - 2026-02-06

### Fixed
- **macOS updater security hardening**:
  - Removed unsafe `eval` execution in network calls
  - Kept `--help` and `--rollback` usable by deferring python dependency enforcement to update-check stage
- **Launcher hardening**:
  - Resolved absolute script path before launch
  - Added missing script existence check and safer AppleScript invocation
- **DMG mount parsing**: Improved mount point extraction for volume names with spaces
- **Windows process handling**: Corrected `Get-Process` error handling placement in `Stop-AntigravityApp`

### Changed
- Synced bundled macOS app resource script with root `antigravity-update.sh`
- Added missing backup/integrity/signature message keys across macOS and Windows locale files
- Bumped application metadata and installer metadata to `1.4.1`

## [1.4.0] - 2026-02-06

### Added
- **Docker Updater**: New script at `docker/antigravity-docker-update.sh`
- Docker updater options:
  - `--check-only` for update checks
  - `--tag` to target a specific Docker image tag
  - `--restart-container` to recreate docker-run based containers with the updated image
- Docker updater documentation at `docker/README.md`

### Changed
- Updated `README.md` with Docker updater installation, usage, requirements, logs, and troubleshooting

## [1.3.0] - 2026-02-06

### Added
- **Linux Support**: New Linux updater script at `linux/antigravity-update.sh`
- Automatic Linux package selection:
  - `.deb` (Debian/Ubuntu derivatives)
  - `.rpm` (Fedora/RHEL/openSUSE derivatives)
  - `.AppImage` fallback when package manager install is not preferred
- Linux documentation at `linux/README.md`

### Changed
- Updated `README.md` to include Linux installation, usage, requirements, logs, and troubleshooting
- Updated platform badge to `macOS | Windows | Linux`

## [1.2.2] - 2026-02-04

### Fixed
- **Windows EXE Detection**: Fixed issue where updater showed "Not installed" even when Antigravity Tools was installed on Windows
- Now detects both `antigravity_tools.exe` (current naming) and `Antigravity Tools.exe` (legacy naming)

### Contributors
- Thanks to [@nvtptest](https://github.com/nvtptest) for reporting and fixing this issue! ([#1](https://github.com/ercanatay/AntigravityUpdater/pull/1))

## [1.2.0] - 2026-01-30

### Added - Security Enhancements
- **Path Traversal Protection**: Locale files are now validated to prevent directory traversal attacks
- **Language Code Validation**: Only valid language codes (2 letters or xx-XX format) are accepted
- **SHA256 Hash Verification**: Support for verifying downloaded file integrity
- **Digital Signature Check**: exe/msi files are checked for valid Authenticode signatures
- **Secure Temp Directory**: Random suffix added to temp directory path
- **Comprehensive Logging**: Full operation logging with automatic rotation (max 1MB)

### Added - New Features
- **Backup System**: Automatic backup before updates (keeps last 3 backups)
- **Rollback**: `--rollback` (macOS) / `-Rollback` (Windows) to restore previous version
- **Check-Only Mode**: `--check-only` (macOS) / `-CheckOnly` (Windows) to check without installing
- **Silent Mode**: `--silent` (macOS) / `-Silent` (Windows) for automated/scripted updates
- **Changelog Display**: `--changelog` (macOS) / `-ShowChangelog` (Windows) to view release notes
- **Proxy Support**: `--proxy` (macOS) / `-ProxyUrl` (Windows) for corporate network environments
- **No Backup Option**: `--no-backup` (macOS) / `-NoBackup` (Windows) to skip backup creation

### Changed
- Improved process termination with more precise matching
- Enhanced error handling and user feedback
- Better User-Agent header for GitHub API requests

### Security Fixes
- Fixed potential arbitrary code execution via malicious locale files
- Fixed predictable temp directory path
- Added TLS 1.2 enforcement for all connections

## [1.1.0] - 2026-01-30

### Added
- **Windows Support**: Full Windows 10/11 64-bit support
  - PowerShell-based updater script
  - Batch file launcher for easy execution
  - Inno Setup installer script for creating `.exe` installer
  - Works on Bootcamp Windows installations
- Windows-specific locale files (PowerShell format)
- Separate `windows/` directory for Windows-specific files
- Build instructions for Windows installer

### Changed
- Updated README.md with Windows installation instructions
- Project now supports both macOS and Windows platforms

### Technical Details
- Windows version uses PowerShell 5.1+ (included with Windows 10/11)
- Installer output: `AntigravityToolsUpdater_x.x.x_x64-setup.exe`
- No admin rights required for installation (installs to user directory)
- Same 51-language support as macOS version

## [1.0.0] - 2026-01-15

### Added
- Initial release
- macOS application bundle (.app)
- 51 language support with automatic detection
- Universal Binary support (Apple Silicon + Intel)
- One-click update functionality
- Persistent language preferences
- Automatic quarantine flag removal
- GitHub API integration for version checking

### Supported Platforms
- macOS 10.15 (Catalina) or later
- Apple Silicon (M1/M2/M3) and Intel Macs
