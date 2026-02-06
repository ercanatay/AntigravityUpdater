#!/usr/bin/env bash

# Antigravity Tools Updater - Linux Version
# Supports .deb, .rpm and AppImage releases from Antigravity-Manager
# Supports 51 languages with shared locale files

set -euo pipefail

UPDATER_VERSION="1.4.2"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALES_DIR="$SCRIPT_DIR/../locales"
LANG_PREF_FILE="$HOME/.antigravity_updater_lang_linux"
SELECTED_LANG="en"

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$XDG_STATE_HOME/AntigravityUpdater"
LOG_FILE="$LOG_DIR/updater.log"
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
MSG_INSTALLING_DEB="Installing .deb package..."
MSG_INSTALLING_RPM="Installing .rpm package..."
MSG_INSTALLING_APPIMAGE="Installing AppImage..."
MSG_INSTALLED_APPIMAGE="Installed AppImage"
MSG_PATH_NOTE="Note"

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

    RELEASE_INFO=$("${curl_cmd[@]}" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" || true)

    if [[ -z "$RELEASE_INFO" ]] || [[ "$RELEASE_INFO" == *"API rate limit exceeded"* ]]; then
        write_log "ERROR" "GitHub API request failed"
        echo "ERROR: $MSG_API_ERROR." >&2
        exit 1
    fi

    LATEST_VERSION=$(printf '%s' "$RELEASE_INFO" | python3 -c 'import json,sys; j=json.load(sys.stdin); print((j.get("tag_name") or "").lstrip("v"))' 2>/dev/null || true)

    if [[ -z "$LATEST_VERSION" ]]; then
        write_log "ERROR" "Could not parse latest version from GitHub response"
        echo "ERROR: Could not parse latest version from GitHub response." >&2
        exit 1
    fi

    RELEASE_BODY=$(printf '%s' "$RELEASE_INFO" | python3 -c 'import json,sys; j=json.load(sys.stdin); print(j.get("body") or "")' 2>/dev/null || true)
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
        rf"_{deb_arch}\.deb$",
        r"\.deb$",
        rf"_{app_arch}\.AppImage$",
        r"\.AppImage$",
        rf"\.{rpm_arch}\.rpm$",
        r"\.rpm$",
    ],
    "rpm": [
        rf"\.{rpm_arch}\.rpm$",
        r"\.rpm$",
        rf"_{app_arch}\.AppImage$",
        r"\.AppImage$",
        rf"_{deb_arch}\.deb$",
        r"\.deb$",
    ],
    "appimage": [
        rf"_{app_arch}\.AppImage$",
        r"\.AppImage$",
        rf"_{deb_arch}\.deb$",
        r"\.deb$",
        rf"\.{rpm_arch}\.rpm$",
        r"\.rpm$",
    ],
}

selected = None
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

if not selected:
    for asset in assets:
        name = asset.get("name") or ""
        if name.lower().endswith(".sig"):
            continue
        lowered = name.lower()
        if lowered.endswith(".deb") or lowered.endswith(".rpm") or lowered.endswith(".appimage"):
            selected = asset
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

    print_msg "$MSG_DOWNLOADING $DOWNLOAD_NAME"
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
                if [[ $# -lt 2 ]]; then
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

    if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
        print_msg "$MSG_ALREADY_LATEST"
        write_log "INFO" "Already on latest version"
        exit 0
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        echo "$MSG_OLD_VERSION: $CURRENT_VERSION"
        echo "$MSG_NEW_VERSION_LABEL: $LATEST_VERSION"
        write_log "INFO" "Check-only mode: update available"
        exit 0
    fi

    select_asset
    print_msg "$MSG_NEW_VERSION"
    print_msg "$MSG_SELECTED_ASSET: $DOWNLOAD_NAME"
    write_log "INFO" "Selected asset: $DOWNLOAD_NAME"

    download_asset
    install_asset

    print_msg ""
    print_msg "$MSG_UPDATE_SUCCESS"
    print_msg "$MSG_OLD_VERSION: $CURRENT_VERSION"
    print_msg "$MSG_NEW_VERSION_LABEL: $LATEST_VERSION"

    write_log "INFO" "Update completed: $CURRENT_VERSION -> $LATEST_VERSION"
}

main "$@"
