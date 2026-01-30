# Windows Build Instructions

This folder contains the Windows version of Antigravity Tools Updater.

## Requirements

- Windows 10 or Windows 11 (64-bit)
- PowerShell 5.1 or later (included with Windows)
- Works on Bootcamp Windows installations

## Running Directly

You can run the updater directly without installation:

```batch
AntigravityUpdater.bat
```

Or via PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File antigravity-update.ps1
```

## Building the Installer

To create the installer (.exe), you need [Inno Setup](https://jrsoftware.org/isinfo.php):

1. Install Inno Setup 6.x
2. Place an icon file at `resources/icon.ico`
3. Open `installer.iss` in Inno Setup Compiler
4. Click "Compile" or press Ctrl+F9
5. The installer will be created in `../releases/`

Output filename: `AntigravityToolsUpdater_1.0.0_x64-setup.exe`

## Command Line Options

```powershell
# Change language
.\antigravity-update.ps1 -Lang

# Reset language preference
.\antigravity-update.ps1 -ResetLang

# Set specific language
.\antigravity-update.ps1 -SetLang tr
```

## Supported Languages

The Windows version supports the same 51 languages as the macOS version.
Language files are located in the `locales/` folder.

## File Structure

```
windows/
├── antigravity-update.ps1    # Main PowerShell script
├── AntigravityUpdater.bat    # Batch launcher
├── installer.iss             # Inno Setup script
├── README.md                 # This file
├── locales/                  # Language files
│   ├── en.ps1
│   ├── tr.ps1
│   └── ...
└── resources/
    └── icon.ico              # Application icon
```
