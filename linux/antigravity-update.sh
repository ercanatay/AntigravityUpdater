#!/usr/bin/env bash
# shellcheck disable=SC2034

# Antigravity Tools Updater - Linux Version
# Supports .deb, .rpm and AppImage releases from Antigravity-Manager
# Supports 51 languages with shared locale files

set -euo pipefail

UPDATER_VERSION="1.7.0"
REPO_OWNER="lbjlaq"
REPO_NAME="Antigravity-Manager"
APP_CMD_NAME="antigravity-tools"

CHECK_ONLY=false
SHOW_CHANGELOG=false
SILENT=false
PROXY_URL=""
REQUESTED_FORMAT="auto"
CHANGE_LANGUAGE=false
RESET_LANG=false
ENABLE_AUTO_UPDATE=false
DISABLE_AUTO_UPDATE=false
AUTO_UPDATE_FREQUENCY=""
GITHUB_TOKEN=""
TARGET_VERSION=""
JSON_OUTPUT=false
SELF_UPDATE=false
ROLLBACK=false
NO_BACKUP=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALES_DIR="$SCRIPT_DIR/../locales"
LANG_PREF_FILE="$HOME/.antigravity_updater_lang_linux"
SELECTED_LANG="en"

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$XDG_STATE_HOME/AntigravityUpdater"
LOG_FILE="$LOG_DIR/updater.log"
BACKUP_DIR="$LOG_DIR/backups"
HISTORY_FILE="$LOG_DIR/update-history.json"
CACHE_FILE="$LOG_DIR/download-cache.json"
HOOKS_DIR="$LOG_DIR/hooks"
TEMP_DIR="$(mktemp -d -t antigravity-updater.XXXXXXXX)"

ARCH_LABEL=""
DEB_ARCH=""
RPM_ARCH=""
APPIMAGE_ARCH=""
ASSET_FORMAT=""
LATEST_VERSION=""
RELEASE_INFO=""
RELEASE_BODY=""
CURRENT_VERSION=""
DOWNLOAD_NAME=""
DOWNLOAD_URL=""
DOWNLOAD_PATH=""

declare -a LANG_CODES=("en" "tr" "de" "fr" "es" "it" "pt" "ru" "zh" "zh-TW" "ja" "ko" "ar" "nl" "pl" "sv" "no" "da" "fi" "uk" "cs" "hi" "el" "he" "th" "vi" "id" "ms" "hu" "ro" "bg" "hr" "sr" "sk" "sl" "lt" "lv" "et" "ca" "eu" "gl" "is" "fa" "sw" "af" "fil" "bn" "ta" "ur" "mi" "cy")
declare -a LANG_NAMES=("English" "Turkce" "Deutsch" "Francais" "Espanol" "Italiano" "Portugues" "Russkiy" "Zhongwen" "Zhongwen-TW" "Nihongo" "Hangugeo" "Arabiya" "Nederlands" "Polski" "Svenska" "Norsk" "Dansk" "Suomi" "Ukrayinska" "Cestina" "Hindi" "Ellinika" "Ivrit" "Thai" "Tieng Viet" "Bahasa Indonesia" "Bahasa Melayu" "Magyar" "Romana" "Balgarski" "Hrvatski" "Srpski" "Slovencina" "Slovenscina" "Lietuviu" "Latviesu" "Eesti" "Catala" "Euskara" "Galego" "Islenska" "Farsi" "Kiswahili" "Afrikaans" "Filipino" "Bangla" "Tamil" "Urdu" "Te Reo Maori" "Cymraeg")

# Default messages (overridden by locale files via source)
MSG_TITLE="Antigravity Tools Updater"
MSG_CHECKING_VERSION="Checking current version..."
MSG_CURRENT="Current"
MSG_NOT_INSTALLED="Not installed"
MSG_UNKNOWN="Unknown"
MSG_CHECKING_LATEST="Checking latest version..."
MSG_LATEST="Latest"
MSG_ARCH="Architecture"
MSG_ALREADY_LATEST="You already have the latest version!"
MSG_NEW_VERSION="New version available! Starting download..."
MSG_DOWNLOADING="Downloading..."
MSG_DOWNLOADING_ASSET="Downloading package..."
MSG_DOWNLOAD_FAILED="Download failed!"
MSG_DOWNLOAD_COMPLETE="Download complete"
MSG_UPDATE_SUCCESS="UPDATE COMPLETED SUCCESSFULLY!"
MSG_OLD_VERSION="Old version"
MSG_NEW_VERSION_LABEL="New version"
MSG_API_ERROR="Cannot access GitHub API"
MSG_SELECT_LANGUAGE="Select language"
LANG_NAME="English"

MSG_PREFERRED_PACKAGE="Preferred package format"
MSG_RELEASE_NOTES="Release notes"
MSG_NO_CHANGELOG="No changelog available."
MSG_SELECTED_ASSET="Selected asset"
MSG_UPDATE_AVAILABLE="Update available"
MSG_AUTO_UPDATE_ENABLED="Automatic updates enabled"
MSG_AUTO_UPDATE_DISABLED="Automatic updates disabled"
MSG_AUTO_UPDATE_INVALID_FREQ="Invalid auto-update frequency"
MSG_AUTO_UPDATE_SUPPORTED="Supported values: hourly, every3hours, every6hours, daily, weekly, monthly"
MSG_INSTALLING_DEB="Installing .deb package..."
MSG_INSTALLING_RPM="Installing .rpm package..."
MSG_INSTALLING_APPIMAGE="Installing AppImage..."
MSG_CLOSING_APP="Closing current application..."
MSG_INSTALLED_APPIMAGE="Installed AppImage"
MSG_PATH_NOTE="Note"
MSG_BACKUP_CREATED="Backup created"
MSG_BACKUP_FAILED="Backup failed"
MSG_ROLLBACK_SUCCESS="Rollback successful"
MSG_ROLLBACK_FAILED="Rollback failed"
MSG_NO_BACKUP="No backup found"
MSG_VERSION_PINNED="Installing specific version"
MSG_SELF_UPDATE_CHECKING="Checking for updater updates..."
MSG_SELF_UPDATE_AVAILABLE="Updater update available"
MSG_SELF_UPDATE_SUCCESS="Updater updated successfully"
MSG_SELF_UPDATE_CURRENT="Updater is up to date"
MSG_HOOK_PRE_UPDATE="Running pre-update hook..."
MSG_HOOK_POST_UPDATE="Running post-update hook..."
MSG_HOOK_FAILED="Hook script failed"
MSG_NOTIFICATION_SENT="Notification sent"
MSG_DOWNLOAD_RETRY="Retrying download..."
MSG_HISTORY_TITLE="Update History"
MSG_HISTORY_EMPTY="No update history"
MSG_CACHE_HIT="Cached version matches, skipping download"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

print_usage() {
    cat <<USAGE
Antigravity Tools Updater v$UPDATER_VERSION (Linux)

Usage: $0 [OPTIONS]

Options:
  --lang, -l          Change language
  --reset-lang        Reset language preference
  --check-only         Check for updates only (no install)
  --changelog          Show release notes before update
  --silent             Run with minimal output
  --proxy URL          Use proxy for HTTP requests
  --format TYPE        auto | deb | rpm | appimage
  --rollback           Roll back from the latest backup
  --no-backup          Skip creating a backup before update
  --token TOKEN        GitHub API token (or set GITHUB_TOKEN env var)
  --version TAG        Install a specific version instead of latest
  --json               Output version info as JSON
  --self-update        Update the updater itself
  --history            Show update history
  --enable-auto-update Enable automatic update checks
  --disable-auto-update Disable automatic update checks
  --auto-update-frequency VALUE
                       hourly | every3hours | every6hours | daily | weekly | monthly
  --help, -h           Show this help
USAGE
}

init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
}

write_log() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true

    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo "0")
        if [[ "$size" -gt 1048576 ]]; then
            tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
}

validate_lang_code() {
    local lang_code="$1"

    if [[ ! "$lang_code" =~ ^[a-z]{2}(-[A-Z]{2})?$ ]]; then
        return 1
    fi

    for code in "${LANG_CODES[@]}"; do
        if [[ "$code" == "$lang_code" ]]; then
            return 0
        fi
    done

    return 1
}

load_language() {
    local lang_code="$1"
    local lang_file="$LOCALES_DIR/${lang_code}.sh"

    if ! validate_lang_code "$lang_code"; then
        return 1
    fi

    if [[ -f "$lang_file" ]]; then
        # shellcheck disable=SC1090
        source "$lang_file"
        SELECTED_LANG="$lang_code"
        return 0
    fi

    if [[ -f "$LOCALES_DIR/en.sh" ]]; then
        # shellcheck disable=SC1090
        source "$LOCALES_DIR/en.sh"
        SELECTED_LANG="en"
        return 0
    fi

    return 1
}

detect_system_language() {
    local sys_lang
    sys_lang=$(echo "${LANG:-en}" | cut -d'_' -f1 | cut -d'.' -f1)

    if validate_lang_code "$sys_lang"; then
        echo "$sys_lang"
        return 0
    fi

    echo "en"
}

show_language_menu() {
    local cols=3
    local count=${#LANG_CODES[@]}
    local rows=$(((count + cols - 1) / cols))
    local choice

    echo ""
    echo "${MSG_SELECT_LANGUAGE}:"
    echo ""

    for ((i=0; i<rows; i++)); do
        for ((j=0; j<cols; j++)); do
            local idx=$((i + j * rows))
            if [[ $idx -lt $count ]]; then
                printf " %2d) %-14s" "$((idx + 1))" "${LANG_NAMES[$idx]}"
            fi
        done
        echo ""
    done

    echo ""
    echo "  0) Auto-detect"
    echo ""
    printf "> "
    read -r choice

    if [[ "$choice" == "0" ]]; then
        SELECTED_LANG=$(detect_system_language)
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$count" ]]; then
        SELECTED_LANG="${LANG_CODES[$((choice - 1))]}"
    else
        SELECTED_LANG="en"
    fi

    echo "$SELECTED_LANG" > "$LANG_PREF_FILE"
    load_language "$SELECTED_LANG" || true
}

check_language_preference() {
    if [[ -f "$LANG_PREF_FILE" ]]; then
        local saved_lang
        saved_lang=$(cat "$LANG_PREF_FILE")
        if load_language "$saved_lang"; then
            return 0
        fi
    fi
    return 1
}

print_msg() {
    if [[ "$SILENT" != true ]]; then
        echo "$1"
    fi
}

run_privileged() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
        return
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
        return
    fi

    write_log "ERROR" "Root privileges are required for package installation"
    echo "ERROR: Root privileges are required for package installation." >&2
    echo "Please rerun with root access or install sudo." >&2
    exit 1
}

extract_version() {
    local input="$1"
    echo "$input" | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1 || true
}

detect_arch() {
    local machine

    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64)
            ARCH_LABEL="x86_64"
            DEB_ARCH="amd64"
            RPM_ARCH="x86_64"
            APPIMAGE_ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH_LABEL="aarch64"
            DEB_ARCH="arm64"
            RPM_ARCH="aarch64"
            APPIMAGE_ARCH="aarch64"
            ;;
        *)
            write_log "ERROR" "Unsupported CPU architecture: $machine"
            echo "ERROR: Unsupported CPU architecture: $machine" >&2
            exit 1
            ;;
    esac
}

detect_install_format() {
    if [[ "$REQUESTED_FORMAT" != "auto" ]]; then
        ASSET_FORMAT="$REQUESTED_FORMAT"
        return
    fi

    if command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
        ASSET_FORMAT="deb"
        return
    fi

    if command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1 || command -v zypper >/dev/null 2>&1 || command -v rpm >/dev/null 2>&1; then
        ASSET_FORMAT="rpm"
        return
    fi

    ASSET_FORMAT="appimage"
}

# Compare versions (returns 0 if $1 > $2)
version_gt() {
    python3 -c "import sys; v1=[int(x) for x in sys.argv[1].split('-')[0].split('.')]; v2=[int(x) for x in sys.argv[2].split('-')[0].split('.')]; print(1 if v1 > v2 else 0)" "$1" "$2" 2>/dev/null | grep -q 1
}

get_current_version() {
    local detected=""

    if command -v "$APP_CMD_NAME" >/dev/null 2>&1; then
        detected=$($APP_CMD_NAME --version 2>/dev/null || $APP_CMD_NAME -V 2>/dev/null || true)
        detected=$(extract_version "$detected")
    fi

    if [[ -z "$detected" ]] && command -v dpkg-query >/dev/null 2>&1; then
        detected=$(dpkg-query -W -f='${Version}\n' antigravity-tools 2>/dev/null || true)
        detected=$(extract_version "$detected")
    fi

    if [[ -z "$detected" ]] && command -v rpm >/dev/null 2>&1; then
        detected=$(rpm -q --queryformat '%{VERSION}\n' antigravity-tools 2>/dev/null || true)
        detected=$(extract_version "$detected")
    fi

    if [[ -z "$detected" ]] && [[ -L "$HOME/.local/bin/antigravity-tools" ]]; then
        detected=$(readlink "$HOME/.local/bin/antigravity-tools" 2>/dev/null || true)
        detected=$(extract_version "$detected")
    fi

    if [[ -n "$detected" ]]; then
        echo "$detected"
        return
    fi

    echo "$MSG_NOT_INSTALLED"
}

fetch_release_info() {
    local curl_cmd
    curl_cmd=(curl -sS -L -A "AntigravityUpdater/$UPDATER_VERSION")

    if [[ -n "$PROXY_URL" ]]; then
        curl_cmd+=(--proxy "$PROXY_URL")
        write_log "INFO" "Using proxy: $PROXY_URL"
    fi
    if [[ -n "$GITHUB_TOKEN" ]]; then
        curl_cmd+=(-H "Authorization: Bearer $GITHUB_TOKEN")
        write_log "INFO" "Using GitHub API token"
    fi

    # Version pinning
    local api_url
    if [[ -n "$TARGET_VERSION" ]]; then
        local pin_tag="$TARGET_VERSION"
        [[ "$pin_tag" =~ ^[0-9] ]] && pin_tag="v$pin_tag"
        api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$pin_tag"
        print_msg "$MSG_VERSION_PINNED: $TARGET_VERSION"
        write_log "INFO" "Version pinning: targeting $pin_tag"
    else
        api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
    fi

    RELEASE_INFO=$("${curl_cmd[@]}" "$api_url" || true)

    if [[ -z "$RELEASE_INFO" ]] || [[ "$RELEASE_INFO" == *"API rate limit exceeded"* ]]; then
        write_log "ERROR" "GitHub API request failed"
        echo "ERROR: $MSG_API_ERROR." >&2
        exit 1
    fi

    # Securely parse JSON without eval by separating fields with newlines
    local release_data
    release_data=$(printf '%s' "$RELEASE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print((data.get('tag_name') or '').lstrip('v')); print(data.get('body') or '')" 2>/dev/null || true)

    LATEST_VERSION=$(printf '%s\n' "$release_data" | head -n1)
    RELEASE_BODY=$(printf '%s\n' "$release_data" | tail -n+2)

    if [[ -z "$LATEST_VERSION" ]]; then
        write_log "ERROR" "Could not parse latest version from GitHub response"
        echo "ERROR: Could not parse latest version from GitHub response." >&2
        exit 1
    fi
}

select_asset() {
    local selection

    selection=$(RELEASE_INFO_JSON="$RELEASE_INFO" TARGET_FORMAT="$ASSET_FORMAT" DEB_ARCH="$DEB_ARCH" RPM_ARCH="$RPM_ARCH" APPIMAGE_ARCH="$APPIMAGE_ARCH" python3 - <<'PY'
import json
import os
import re
import sys

release = json.loads(os.environ["RELEASE_INFO_JSON"])
assets = release.get("assets") or []

fmt = os.environ["TARGET_FORMAT"]
deb_arch = os.environ["DEB_ARCH"]
rpm_arch = os.environ["RPM_ARCH"]
app_arch = os.environ["APPIMAGE_ARCH"]

patterns = {
    "deb": [
        rf"[_.-]{deb_arch}\.deb$",
        rf"[_.-]{app_arch}\.AppImage$",
        rf"[_.-]{rpm_arch}\.rpm$",
    ],
    "rpm": [
        rf"[_.-]{rpm_arch}\.rpm$",
        rf"[_.-]{app_arch}\.AppImage$",
        rf"[_.-]{deb_arch}\.deb$",
    ],
    "appimage": [
        rf"[_.-]{app_arch}\.AppImage$",
        rf"[_.-]{deb_arch}\.deb$",
        rf"[_.-]{rpm_arch}\.rpm$",
    ],
}

selected = None
# Try specific architecture matches first
for pattern in patterns.get(fmt, []):
    for asset in assets:
        name = asset.get("name") or ""
        if not name or name.lower().endswith(".sig"):
            continue
        if re.search(pattern, name, re.IGNORECASE):
            selected = asset
            break
    if selected:
        break

# Fallback: strict generic match (no arch in name, or explicit 'noarch'/'universal')
# We do NOT blind match any .deb/.rpm to avoid installing wrong arch (e.g. amd64 on arm64)
if not selected:
    generic_patterns = {
        "deb": [r"[_.-]all\.deb$", r"[_.-]noarch\.deb$", r"[_.-]universal\.deb$"],
        "rpm": [r"[_.-]noarch\.rpm$", r"[_.-]all\.rpm$", r"[_.-]universal\.rpm$"],
        "appimage": [r"[_.-]noarch\.AppImage$", r"[_.-]universal\.AppImage$"]
    }

    # Also allow bare extensions if we are desperate, but only if they don't contain conflicting arch strings?
    # Actually, bare extension usually implies source or universal.
    # But safer to just stick to what we know or fail.

    for pattern in generic_patterns.get(fmt, []):
        for asset in assets:
            name = asset.get("name") or ""
            if not name or name.lower().endswith(".sig"):
                continue
            if re.search(pattern, name, re.IGNORECASE):
                selected = asset
                break
        if selected:
            break

if not selected:
    sys.exit(1)

name = selected.get("name")
url = selected.get("browser_download_url")
if not name or not url:
    sys.exit(1)

print(name)
print(url)
PY
)

    if [[ -z "$selection" ]]; then
        write_log "ERROR" "No compatible Linux asset found in release"
        echo "ERROR: No compatible Linux package found in release assets." >&2
        exit 1
    fi

    DOWNLOAD_NAME=$(printf '%s\n' "$selection" | sed -n '1p')
    DOWNLOAD_URL=$(printf '%s\n' "$selection" | sed -n '2p')
    DOWNLOAD_PATH="$TEMP_DIR/$DOWNLOAD_NAME"
}

download_asset() {
    local curl_cmd
    curl_cmd=(curl -L --fail -o "$DOWNLOAD_PATH")

    if [[ "$SILENT" != true ]]; then
        curl_cmd+=(--progress-bar)
    else
        curl_cmd+=(-sS)
    fi

    if [[ -n "$PROXY_URL" ]]; then
        curl_cmd+=(--proxy "$PROXY_URL")
    fi

    print_msg "$MSG_DOWNLOADING_ASSET $DOWNLOAD_NAME"
    print_msg "URL: $DOWNLOAD_URL"

    if ! "${curl_cmd[@]}" "$DOWNLOAD_URL"; then
        write_log "ERROR" "Download failed: $DOWNLOAD_URL"
        echo "ERROR: Download failed." >&2
        exit 1
    fi

    if [[ ! -s "$DOWNLOAD_PATH" ]]; then
        write_log "ERROR" "Downloaded file is empty: $DOWNLOAD_PATH"
        echo "ERROR: Downloaded file is empty." >&2
        exit 1
    fi

    print_msg "$MSG_DOWNLOAD_COMPLETE"
    write_log "INFO" "Downloaded asset: $DOWNLOAD_NAME"
}

stop_running_app() {
    print_msg "$MSG_CLOSING_APP"
    pkill -x "Antigravity Tools" 2>/dev/null || true
    pkill -x "antigravity-tools" 2>/dev/null || true
    sleep 1
}

install_deb_package() {
    if command -v apt-get >/dev/null 2>&1; then
        if ! run_privileged apt-get install -y "$DOWNLOAD_PATH"; then
            run_privileged dpkg -i "$DOWNLOAD_PATH"
            run_privileged apt-get install -f -y
        fi
        return
    fi

    if command -v dpkg >/dev/null 2>&1; then
        run_privileged dpkg -i "$DOWNLOAD_PATH"
        return
    fi

    write_log "ERROR" "No .deb installer tooling found"
    echo "ERROR: No .deb installer tooling found (apt-get/dpkg missing)." >&2
    exit 1
}

install_rpm_package() {
    if command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y "$DOWNLOAD_PATH"
        return
    fi

    if command -v yum >/dev/null 2>&1; then
        if ! run_privileged yum localinstall -y "$DOWNLOAD_PATH"; then
            run_privileged yum install -y "$DOWNLOAD_PATH"
        fi
        return
    fi

    if command -v zypper >/dev/null 2>&1; then
        run_privileged zypper --non-interactive install --allow-unsigned-rpm "$DOWNLOAD_PATH"
        return
    fi

    if command -v rpm >/dev/null 2>&1; then
        run_privileged rpm -Uvh "$DOWNLOAD_PATH"
        return
    fi

    write_log "ERROR" "No .rpm installer tooling found"
    echo "ERROR: No .rpm installer tooling found (dnf/yum/zypper/rpm missing)." >&2
    exit 1
}

install_appimage() {
    local install_dir
    local target_path

    install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"

    target_path="$install_dir/Antigravity.Tools_${LATEST_VERSION}_${APPIMAGE_ARCH}.AppImage"

    cp "$DOWNLOAD_PATH" "$target_path"
    chmod +x "$target_path"
    ln -sfn "$target_path" "$install_dir/antigravity-tools"

    print_msg "$MSG_INSTALLED_APPIMAGE: $target_path"
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_msg "$MSG_PATH_NOTE: $install_dir is not in PATH. Add it to run 'antigravity-tools' directly."
    fi

    write_log "INFO" "Installed AppImage to $target_path"
}

install_asset() {
    stop_running_app

    case "$DOWNLOAD_NAME" in
        *.deb)
            print_msg "$MSG_INSTALLING_DEB"
            install_deb_package
            ;;
        *.rpm)
            print_msg "$MSG_INSTALLING_RPM"
            install_rpm_package
            ;;
        *.AppImage)
            print_msg "$MSG_INSTALLING_APPIMAGE"
            install_appimage
            ;;
        *)
            write_log "ERROR" "Unsupported downloaded asset: $DOWNLOAD_NAME"
            echo "ERROR: Unsupported downloaded asset: $DOWNLOAD_NAME" >&2
            exit 1
            ;;
    esac
}

validate_format() {
    case "$REQUESTED_FORMAT" in
        auto|deb|rpm|appimage)
            ;;
        *)
            echo "ERROR: Invalid --format value: $REQUESTED_FORMAT" >&2
            echo "Valid values: auto, deb, rpm, appimage" >&2
            exit 1
            ;;
    esac
}

get_frequency_seconds() {
    case "$1" in
        hourly) echo 3600 ;;
        every3hours) echo 10800 ;;
        every6hours) echo 21600 ;;
        daily) echo 86400 ;;
        weekly) echo 604800 ;;
        monthly) echo 2592000 ;;
        *) return 1 ;;
    esac
}

# Backup & Rollback Functions

create_backup() {
    local pkg_type="$1"

    mkdir -p "$BACKUP_DIR"

    local timestamp
    timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_name="backup_${timestamp}"
    local backup_path="$BACKUP_DIR/$backup_name"
    mkdir -p "$backup_path"

    case "$pkg_type" in
        deb)
            if command -v dpkg-query >/dev/null 2>&1; then
                dpkg-query -W -f='${Package} ${Version}\n' antigravity-tools > "$backup_path/package-info.txt" 2>/dev/null || true
            fi
            ;;
        rpm)
            if command -v rpm >/dev/null 2>&1; then
                rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE}\n' antigravity-tools > "$backup_path/package-info.txt" 2>/dev/null || true
            fi
            ;;
        appimage)
            if [[ -L "$HOME/.local/bin/antigravity-tools" ]]; then
                local target
                target=$(readlink "$HOME/.local/bin/antigravity-tools" 2>/dev/null || true)
                if [[ -f "$target" ]]; then
                    cp "$target" "$backup_path/" 2>/dev/null || true
                    echo "$target" > "$backup_path/appimage-path.txt"
                fi
            fi
            ;;
    esac

    # Save the downloaded package for rollback
    if [[ -n "${DOWNLOAD_PATH:-}" ]] && [[ -f "${DOWNLOAD_PATH:-}" ]]; then
        cp "$DOWNLOAD_PATH" "$backup_path/" 2>/dev/null || true
    fi

    echo "$ASSET_FORMAT" > "$backup_path/format.txt"

    # Keep only last 3 backups
    local backups=()
    local backup
    shopt -s nullglob
    for backup in "$BACKUP_DIR"/backup_*; do
        [[ -d "$backup" ]] || continue
        backups+=("$backup")
    done
    shopt -u nullglob

    if [[ ${#backups[@]} -gt 3 ]]; then
        local remove_count=$(( ${#backups[@]} - 3 ))
        for ((i=0; i<remove_count; i++)); do
            rm -rf "${backups[$i]}"
        done
    fi

    write_log "INFO" "Backup created: $backup_path"
    echo "$backup_path"
}

restore_backup() {
    local backups=()
    local backup
    shopt -s nullglob
    for backup in "$BACKUP_DIR"/backup_*; do
        [[ -d "$backup" ]] || continue
        backups+=("$backup")
    done
    shopt -u nullglob

    local latest_backup=""
    if [[ ${#backups[@]} -gt 0 ]]; then
        latest_backup="${backups[${#backups[@]}-1]}"
    fi

    if [[ -z "$latest_backup" ]] || [[ ! -d "$latest_backup" ]]; then
        echo "ERROR: $MSG_NO_BACKUP"
        write_log "ERROR" "No backup found for rollback"
        return 1
    fi

    local fmt=""
    if [[ -f "$latest_backup/format.txt" ]]; then
        fmt=$(cat "$latest_backup/format.txt")
    fi

    case "$fmt" in
        appimage)
            if [[ -f "$latest_backup/appimage-path.txt" ]]; then
                local orig_path
                orig_path=$(cat "$latest_backup/appimage-path.txt")
                local appimage_file
                appimage_file=$(find "$latest_backup" -maxdepth 1 -name "*.AppImage" | head -1)
                if [[ -f "$appimage_file" ]]; then
                    cp "$appimage_file" "$orig_path"
                    chmod +x "$orig_path"
                    echo "$MSG_ROLLBACK_SUCCESS"
                    write_log "INFO" "Rollback successful (AppImage)"
                    return 0
                fi
            fi
            ;;
        deb)
            local deb_file
            deb_file=$(find "$latest_backup" -maxdepth 1 -name "*.deb" | head -1)
            if [[ -f "$deb_file" ]]; then
                if command -v apt-get >/dev/null 2>&1; then
                    run_privileged apt-get install -y --allow-downgrades "$deb_file"
                else
                    run_privileged dpkg -i "$deb_file"
                fi
                echo "$MSG_ROLLBACK_SUCCESS"
                write_log "INFO" "Rollback successful (deb)"
                return 0
            fi
            ;;
        rpm)
            local rpm_file
            rpm_file=$(find "$latest_backup" -maxdepth 1 -name "*.rpm" | head -1)
            if [[ -f "$rpm_file" ]]; then
                if command -v dnf >/dev/null 2>&1; then
                    run_privileged dnf downgrade -y "$rpm_file"
                elif command -v rpm >/dev/null 2>&1; then
                    run_privileged rpm -Uvh --oldpackage "$rpm_file"
                fi
                echo "$MSG_ROLLBACK_SUCCESS"
                write_log "INFO" "Rollback successful (rpm)"
                return 0
            fi
            ;;
    esac

    echo "ERROR: $MSG_ROLLBACK_FAILED"
    write_log "ERROR" "Rollback failed"
    return 1
}

# Hook Functions

run_hook() {
    local hook_name="$1"
    local hook_script="$HOOKS_DIR/${hook_name}.sh"

    if [[ ! -f "$hook_script" ]]; then
        return 0
    fi

    [[ ! -x "$hook_script" ]] && chmod +x "$hook_script" 2>/dev/null || true

    print_msg "$MSG_HOOK_PRE_UPDATE"
    write_log "INFO" "Running hook: $hook_name"

    if ! OLD_VERSION="${CURRENT_VERSION:-}" NEW_VERSION="${LATEST_VERSION:-}" PLATFORM="linux" bash "$hook_script"; then
        write_log "ERROR" "Hook failed: $hook_name"
        print_msg "ERROR: $MSG_HOOK_FAILED: $hook_name"
        return 1
    fi

    write_log "INFO" "Hook completed: $hook_name"
    return 0
}

# Notification Functions

send_notification() {
    local title="$1"
    local message="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" 2>/dev/null || true
        write_log "INFO" "Desktop notification sent"
    fi
}

# History Functions

write_history() {
    local from_ver="$1" to_ver="$2" status="$3" asset="${4:-}"
    local timestamp
    timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

    local entry
    entry=$(python3 -c "
import json, sys
entry = {'timestamp': sys.argv[1], 'from_version': sys.argv[2], 'to_version': sys.argv[3],
         'status': sys.argv[4], 'platform': 'linux', 'asset': sys.argv[5]}
print(json.dumps(entry))
" "$timestamp" "$from_ver" "$to_ver" "$status" "$asset" 2>/dev/null) || return 0

    if [[ -f "$HISTORY_FILE" ]]; then
        local updated
        updated=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f: history = json.load(f)
except: history = []
history.append(json.loads(sys.argv[2]))
history = history[-50:]
print(json.dumps(history, indent=2))
" "$HISTORY_FILE" "$entry" 2>/dev/null) || return 0
        printf '%s\n' "$updated" > "$HISTORY_FILE"
    else
        printf '[%s]\n' "$entry" > "$HISTORY_FILE"
    fi
}

show_history() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo "$MSG_HISTORY_EMPTY"
        return
    fi
    echo "$MSG_HISTORY_TITLE"
    python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f: history = json.load(f)
    for e in history[-10:]:
        print(f\"  {e['timestamp']}  {e['from_version']} -> {e['to_version']}  [{e['status']}]  {e.get('asset','')}\")
except: print('  No history available')
" "$HISTORY_FILE" 2>/dev/null
}

# Cache Functions

check_download_cache() {
    local latest_ver="$1"
    [[ ! -f "$CACHE_FILE" ]] && return 1
    local result
    result=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f: cache = json.load(f)
    print('match' if cache.get('version') == sys.argv[2] else 'mismatch')
except: print('error')
" "$CACHE_FILE" "$latest_ver" 2>/dev/null)
    [[ "$result" == "match" ]]
}

update_download_cache() {
    local version="$1" hash="${2:-}"
    python3 -c "
import json, sys
cache = {'version': sys.argv[1], 'hash': sys.argv[2], 'platform': 'linux'}
with open(sys.argv[3], 'w') as f: json.dump(cache, f, indent=2)
" "$version" "$hash" "$CACHE_FILE" 2>/dev/null || true
}

# Download with Retry

download_with_retry() {
    local url="$1" output="$2"
    local max_retries=3 attempt=1

    while [[ $attempt -le $max_retries ]]; do
        local dl_opts=(curl -L -C - --fail -o "$output")
        if [[ "$SILENT" != true ]]; then
            dl_opts+=(--progress-bar)
        else
            dl_opts+=(-sS)
        fi
        [[ -n "$PROXY_URL" ]] && dl_opts+=(--proxy "$PROXY_URL")
        [[ -n "$GITHUB_TOKEN" ]] && dl_opts+=(-H "Authorization: Bearer $GITHUB_TOKEN")

        if "${dl_opts[@]}" "$url" 2>/dev/null; then
            return 0
        fi

        if [[ $attempt -lt $max_retries ]]; then
            local wait_time=$((attempt * 2))
            print_msg "$MSG_DOWNLOAD_RETRY (attempt $((attempt+1))/$max_retries)"
            write_log "WARN" "Download attempt $attempt failed, retrying in ${wait_time}s"
            sleep "$wait_time"
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

# JSON Output

output_json() {
    local current="$1" latest="$2" available="$3" asset="${4:-}"
    python3 -c "
import json, sys
data = {'current_version': sys.argv[1], 'latest_version': sys.argv[2],
        'update_available': sys.argv[3] == 'true', 'platform': 'linux', 'asset': sys.argv[4] if len(sys.argv) > 4 else ''}
print(json.dumps(data, indent=2))
" "$current" "$latest" "$available" "$asset" 2>/dev/null
}

# Self-Update

self_update() {
    print_msg "$MSG_SELF_UPDATE_CHECKING"
    write_log "INFO" "Checking for updater self-update"

    local self_curl=(curl -sS -L -A "AntigravityUpdater/$UPDATER_VERSION")
    [[ -n "$PROXY_URL" ]] && self_curl+=(--proxy "$PROXY_URL")
    [[ -n "$GITHUB_TOKEN" ]] && self_curl+=(-H "Authorization: Bearer $GITHUB_TOKEN")

    local self_info
    self_info=$("${self_curl[@]}" "https://api.github.com/repos/ercanatay/AntigravityUpdater/releases/latest" 2>/dev/null) || {
        echo "ERROR: $MSG_API_ERROR" >&2
        return 1
    }

    local self_ver
    self_ver=$(printf '%s' "$self_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','').lstrip('v'))" 2>/dev/null)

    if [[ -z "$self_ver" ]]; then return 1; fi

    if [[ "$self_ver" == "$UPDATER_VERSION" ]] || ! version_gt "$self_ver" "$UPDATER_VERSION"; then
        print_msg "$MSG_SELF_UPDATE_CURRENT ($UPDATER_VERSION)"
        return 0
    fi

    print_msg "$MSG_SELF_UPDATE_AVAILABLE: $UPDATER_VERSION -> $self_ver"

    local tarball_url
    tarball_url=$(printf '%s' "$self_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tarball_url',''))" 2>/dev/null)
    [[ -z "$tarball_url" ]] && return 1

    local self_tmp="$TEMP_DIR/self-update.tar.gz"
    local dl_opts=(-L -o "$self_tmp" -sS)
    [[ -n "$PROXY_URL" ]] && dl_opts+=(--proxy "$PROXY_URL")
    [[ -n "$GITHUB_TOKEN" ]] && dl_opts+=(-H "Authorization: Bearer $GITHUB_TOKEN")

    curl "${dl_opts[@]}" "$tarball_url" 2>/dev/null || return 1

    local extract_dir="$TEMP_DIR/self-update-extract"
    mkdir -p "$extract_dir"
    tar -xzf "$self_tmp" -C "$extract_dir" --strip-components=1 2>/dev/null || return 1

    [[ -f "$extract_dir/linux/antigravity-update.sh" ]] && cp "$extract_dir/linux/antigravity-update.sh" "$SCRIPT_DIR/antigravity-update.sh" && chmod +x "$SCRIPT_DIR/antigravity-update.sh"
    [[ -d "$extract_dir/locales" ]] && cp -R "$extract_dir/locales/"* "$LOCALES_DIR/" 2>/dev/null || true

    print_msg "$MSG_SELF_UPDATE_SUCCESS: $self_ver"
    write_log "INFO" "Updater self-updated: $UPDATER_VERSION -> $self_ver"
    exit 0
}

configure_auto_update() {
    local frequency="${AUTO_UPDATE_FREQUENCY:-daily}"
    local seconds
    seconds=$(get_frequency_seconds "$frequency") || {
        echo "ERROR: $MSG_AUTO_UPDATE_INVALID_FREQ: $frequency" >&2
        echo "$MSG_AUTO_UPDATE_SUPPORTED" >&2
        exit 1
    }

    local systemd_user_dir="$HOME/.config/systemd/user"
    local service_file="$systemd_user_dir/antigravity-updater.service"
    local timer_file="$systemd_user_dir/antigravity-updater.timer"
    local script_path
    script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

    mkdir -p "$systemd_user_dir"

    if [[ "$DISABLE_AUTO_UPDATE" == true ]]; then
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user disable --now antigravity-updater.timer >/dev/null 2>&1 || true
            systemctl --user daemon-reload >/dev/null 2>&1 || true
        fi
        rm -f "$service_file" "$timer_file"
        print_msg "$MSG_AUTO_UPDATE_DISABLED"
        write_log "INFO" "Automatic updates disabled"
        exit 0
    fi

    cat > "$service_file" <<EOF
[Unit]
Description=Antigravity Updater automatic update check

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash $script_path --silent
EOF

    cat > "$timer_file" <<EOF
[Unit]
Description=Run Antigravity Updater automatic checks

[Timer]
OnBootSec=5m
OnUnitActiveSec=${seconds}
Persistent=true

[Install]
WantedBy=timers.target
EOF

    if ! command -v systemctl >/dev/null 2>&1; then
        echo "ERROR: systemctl is required to manage auto-update timer." >&2
        exit 1
    fi

    systemctl --user daemon-reload
    systemctl --user enable --now antigravity-updater.timer

    print_msg "$MSG_AUTO_UPDATE_ENABLED ($frequency)"
    write_log "INFO" "Automatic updates enabled with frequency: $frequency"
    exit 0
}

main() {
    init_logging
    write_log "INFO" "=== Linux updater started v$UPDATER_VERSION ==="

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang|-l)
                CHANGE_LANGUAGE=true
                ;;
            --reset-lang)
                RESET_LANG=true
                ;;
            --check-only)
                CHECK_ONLY=true
                ;;
            --changelog)
                SHOW_CHANGELOG=true
                ;;
            --silent)
                SILENT=true
                ;;
            --proxy)
                if [[ $# -lt 2 ]] || [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo "ERROR: --proxy requires a value" >&2
                    exit 1
                fi
                PROXY_URL="$2"
                shift
                ;;
            --format)
                if [[ $# -lt 2 ]]; then
                    echo "ERROR: --format requires a value" >&2
                    exit 1
                fi
                REQUESTED_FORMAT="$2"
                shift
                ;;
            --rollback)
                ROLLBACK=true
                ;;
            --no-backup)
                NO_BACKUP=true
                ;;
            --token)
                if [[ $# -lt 2 ]]; then
                    echo "ERROR: --token requires a value" >&2
                    exit 1
                fi
                GITHUB_TOKEN="$2"
                shift
                ;;
            --version)
                if [[ $# -lt 2 ]]; then
                    echo "ERROR: --version requires a value" >&2
                    exit 1
                fi
                TARGET_VERSION="$2"
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                ;;
            --self-update)
                SELF_UPDATE=true
                ;;
            --history)
                init_logging
                show_history
                exit 0
                ;;
            --enable-auto-update)
                ENABLE_AUTO_UPDATE=true
                ;;
            --disable-auto-update)
                DISABLE_AUTO_UPDATE=true
                ;;
            --auto-update-frequency)
                if [[ $# -lt 2 ]]; then
                    echo "ERROR: --auto-update-frequency requires a value" >&2
                    exit 1
                fi
                AUTO_UPDATE_FREQUENCY="$2"
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                print_usage
                exit 1
                ;;
        esac
        shift
    done

    # GITHUB_TOKEN env var fallback
    if [[ -z "$GITHUB_TOKEN" ]] && [[ -n "${GITHUB_TOKEN:-}" ]]; then
        : # already from environment
    fi

    # Handle rollback
    if [[ "$ROLLBACK" == true ]]; then
        write_log "INFO" "Rollback requested"
        if restore_backup; then
            exit 0
        else
            exit 1
        fi
    fi

    # Handle self-update
    if [[ "$SELF_UPDATE" == true ]]; then
        self_update
    fi

    if [[ "$ENABLE_AUTO_UPDATE" == true ]] || [[ "$DISABLE_AUTO_UPDATE" == true ]]; then
        configure_auto_update
    fi

    if [[ "$RESET_LANG" == true ]]; then
        rm -f "$LANG_PREF_FILE"
    fi

    if [[ "$CHANGE_LANGUAGE" == true ]]; then
        if [[ "$SILENT" == true ]]; then
            load_language "en" || true
            SELECTED_LANG="en"
        else
            show_language_menu
        fi
    elif ! check_language_preference; then
        if [[ "$SILENT" == true ]]; then
            load_language "en" || true
            SELECTED_LANG="en"
        else
            SELECTED_LANG=$(detect_system_language)
            load_language "$SELECTED_LANG" || true
            echo "$SELECTED_LANG" > "$LANG_PREF_FILE"
        fi
    fi

    validate_format
    detect_arch
    detect_install_format

    print_msg "$MSG_TITLE v$UPDATER_VERSION (Linux)"
    print_msg "$LANG_NAME (--lang to change)"
    print_msg "$MSG_CHECKING_VERSION"
    print_msg "$MSG_ARCH: $ARCH_LABEL"
    print_msg "$MSG_PREFERRED_PACKAGE: $ASSET_FORMAT"

    CURRENT_VERSION=$(get_current_version)
    print_msg "$MSG_CURRENT: $CURRENT_VERSION"
    write_log "INFO" "Current version: $CURRENT_VERSION"

    print_msg "$MSG_CHECKING_LATEST"
    fetch_release_info
    print_msg "$MSG_LATEST: $LATEST_VERSION"
    write_log "INFO" "Latest version: $LATEST_VERSION"

    if [[ "$SHOW_CHANGELOG" == true ]]; then
        print_msg ""
        print_msg "$MSG_RELEASE_NOTES:"
        print_msg "-------------------------"
        if [[ -n "$RELEASE_BODY" ]]; then
            print_msg "$RELEASE_BODY"
        else
            print_msg "$MSG_NO_CHANGELOG"
        fi
        print_msg "-------------------------"
        print_msg ""
    fi

    # Only compare versions when current version looks like a valid version number;
    # otherwise (e.g. "Not installed") always proceed with the update.
    local update_available=false
    if [[ "$CURRENT_VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]] || ! version_gt "$LATEST_VERSION" "$CURRENT_VERSION"; then
            if [[ "$JSON_OUTPUT" == true ]]; then
                output_json "$CURRENT_VERSION" "$LATEST_VERSION" "false"
                exit 0
            fi
            print_msg "$MSG_ALREADY_LATEST"
            write_log "INFO" "Already on latest version (Current: $CURRENT_VERSION, Latest: $LATEST_VERSION)"
            exit 0
        else
            update_available=true
        fi
    else
        update_available=true
        write_log "INFO" "Current version is not numeric ('$CURRENT_VERSION'), proceeding with update"
    fi

    # JSON output mode
    if [[ "$JSON_OUTPUT" == true ]]; then
        output_json "$CURRENT_VERSION" "$LATEST_VERSION" "$update_available"
        exit 0
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        echo "$MSG_OLD_VERSION: $CURRENT_VERSION"
        echo "$MSG_NEW_VERSION_LABEL: $LATEST_VERSION"
        write_log "INFO" "Check-only mode: update available"
        exit 0
    fi

    # Check download cache
    if check_download_cache "$LATEST_VERSION"; then
        print_msg "$MSG_CACHE_HIT"
        write_log "INFO" "Download cache hit for version $LATEST_VERSION"
    fi

    # Run pre-update hook
    if ! run_hook "pre-update"; then
        write_log "ERROR" "Pre-update hook failed, aborting update"
        exit 1
    fi

    select_asset
    print_msg "$MSG_NEW_VERSION"
    print_msg "$MSG_SELECTED_ASSET: $DOWNLOAD_NAME"
    write_log "INFO" "Selected asset: $DOWNLOAD_NAME"

    # Create backup before update
    if [[ "$NO_BACKUP" != true ]]; then
        print_msg "Creating backup..."
        local backup_path
        backup_path=$(create_backup "$ASSET_FORMAT")
        if [[ -n "$backup_path" ]]; then
            print_msg "$MSG_BACKUP_CREATED"
        else
            print_msg "$MSG_BACKUP_FAILED"
        fi
    fi

    # Download with retry
    DOWNLOAD_PATH="$TEMP_DIR/$DOWNLOAD_NAME"
    print_msg "$MSG_DOWNLOADING $DOWNLOAD_NAME"
    print_msg "URL: $DOWNLOAD_URL"
    if ! download_with_retry "$DOWNLOAD_URL" "$DOWNLOAD_PATH"; then
        write_log "ERROR" "Download failed after retries"
        echo "ERROR: Download failed." >&2
        exit 1
    fi

    if [[ ! -s "$DOWNLOAD_PATH" ]]; then
        write_log "ERROR" "Downloaded file is empty: $DOWNLOAD_PATH"
        echo "ERROR: Downloaded file is empty." >&2
        exit 1
    fi

    print_msg "$MSG_DOWNLOAD_COMPLETE"
    write_log "INFO" "Downloaded asset: $DOWNLOAD_NAME"

    install_asset

    print_msg ""
    print_msg "$MSG_UPDATE_SUCCESS"
    print_msg "$MSG_OLD_VERSION: $CURRENT_VERSION"
    print_msg "$MSG_NEW_VERSION_LABEL: $LATEST_VERSION"

    write_log "INFO" "Update completed: $CURRENT_VERSION -> $LATEST_VERSION"

    # Post-update hook
    run_hook "post-update" || true

    # Record history
    write_history "$CURRENT_VERSION" "$LATEST_VERSION" "success" "$DOWNLOAD_NAME"

    # Update cache
    update_download_cache "$LATEST_VERSION" ""

    # Send notification
    send_notification "$MSG_TITLE" "$MSG_UPDATE_SUCCESS: $LATEST_VERSION"
}

main "$@"
