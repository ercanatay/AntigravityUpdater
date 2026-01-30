# Windows Build Instructions

This folder contains the Windows version of Antigravity Tools Updater.

## Version 1.2.0 - Security Enhanced

## Requirements

- Windows 10 or Windows 11 (64-bit)
- PowerShell 5.1 or later (included with Windows)
- Works on Bootcamp Windows installations

## Features

### Security
- ✅ Path traversal protection for locale files
- ✅ Language code validation
- ✅ SHA256 hash verification support
- ✅ Digital signature checking for exe/msi files
- ✅ Secure random temp directory
- ✅ TLS 1.2 enforced

### Backup & Recovery
- ✅ Automatic backup before updates
- ✅ Rollback to previous version
- ✅ Keeps last 3 backups

### Logging
- ✅ Full operation logging
- ✅ Log rotation (max 1MB)
- ✅ Log location: `%APPDATA%\AntigravityUpdater\updater.log`

### Additional Features
- ✅ Proxy support for corporate networks
- ✅ Check-only mode (no installation)
- ✅ Silent mode for automation
- ✅ Changelog display
- ✅ 51 language support

## Running Directly

```batch
AntigravityUpdater.bat
```

Or via PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File antigravity-update.ps1
```

## Command Line Options

```powershell
# Change language
.\antigravity-update.ps1 -Lang

# Reset language preference
.\antigravity-update.ps1 -ResetLang

# Set specific language
.\antigravity-update.ps1 -SetLang tr

# Check for updates only (no install)
.\antigravity-update.ps1 -CheckOnly

# Show changelog
.\antigravity-update.ps1 -ShowChangelog

# Rollback to previous version
.\antigravity-update.ps1 -Rollback

# Silent mode (no prompts)
.\antigravity-update.ps1 -Silent

# Skip backup
.\antigravity-update.ps1 -NoBackup

# Use proxy
.\antigravity-update.ps1 -ProxyUrl "http://proxy.company.com:8080"
```

## Building the Installer

To create the installer (.exe), you need [Inno Setup](https://jrsoftware.org/isinfo.php):

1. Install Inno Setup 6.x
2. Place an icon file at `resources/icon.ico`
3. Open `installer.iss` in Inno Setup Compiler
4. Click "Compile" or press Ctrl+F9
5. The installer will be created in `../releases/`

Output filename: `AntigravityToolsUpdater_1.2.0_x64-setup.exe`

## File Structure

```
windows/
├── antigravity-update.ps1    # Main PowerShell script
├── AntigravityUpdater.bat    # Batch launcher
├── installer.iss             # Inno Setup script
├── README.md                 # This file
├── locales/                  # Language files (51)
│   ├── en.ps1
│   ├── tr.ps1
│   └── ...
└── resources/
    └── icon.ico              # Application icon
```

## Log Files

Logs are stored in: `%APPDATA%\AntigravityUpdater\`

- `updater.log` - Operation log
- `backups/` - Previous version backups

## Security Notes

1. **TLS 1.2**: All connections use TLS 1.2 minimum
2. **Signature Check**: Downloaded exe/msi files are checked for valid digital signatures
3. **Path Validation**: Locale files are validated to prevent path traversal attacks
4. **Temp Security**: Random suffix added to temp directory to prevent prediction attacks
