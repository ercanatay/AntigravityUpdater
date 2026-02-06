# Linux Build and Usage

This folder contains the Linux updater script for Antigravity Tools.
It supports the shared 51-language locale set used across the project.

## Supported Package Types

- `.deb` (Debian/Ubuntu and derivatives)
- `.rpm` (Fedora/RHEL/openSUSE and derivatives)
- `.AppImage` (fallback for any distribution)

The script automatically detects architecture and preferred package type.

## Requirements

- Bash
- `curl`
- `python3` (used for JSON parsing)
- One of:
  - `apt-get`/`dpkg` for `.deb`
  - `dnf`, `yum`, `zypper`, or `rpm` for `.rpm`
  - no package manager required for `.AppImage`

## Run

```bash
chmod +x antigravity-update.sh
./antigravity-update.sh
```

## Options

```bash
# Change language
./antigravity-update.sh --lang

# Reset saved language preference
./antigravity-update.sh --reset-lang

# Check for updates only
./antigravity-update.sh --check-only

# Show changelog before install
./antigravity-update.sh --changelog

# Silent mode
./antigravity-update.sh --silent

# Use a proxy
./antigravity-update.sh --proxy "http://proxy.company.com:8080"

# Force package type (auto|deb|rpm|appimage)
./antigravity-update.sh --format deb
```

## Logs

- `$XDG_STATE_HOME/AntigravityUpdater/updater.log`
- If `XDG_STATE_HOME` is not set: `~/.local/state/AntigravityUpdater/updater.log`
