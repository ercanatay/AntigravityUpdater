# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- **Rollback**: `-Rollback` flag to restore previous version
- **Check-Only Mode**: `-CheckOnly` flag to check for updates without installing
- **Silent Mode**: `-Silent` flag for automated/scripted updates
- **Changelog Display**: `-ShowChangelog` flag to view release notes
- **Proxy Support**: `-ProxyUrl` parameter for corporate network environments
- **No Backup Option**: `-NoBackup` flag to skip backup creation

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
