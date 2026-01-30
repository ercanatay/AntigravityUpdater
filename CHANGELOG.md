# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
