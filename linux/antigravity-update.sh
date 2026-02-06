#!/usr/bin/env bash

# Antigravity Tools Updater - Linux Version
# Supports .deb, .rpm and AppImage releases from Antigravity-Manager

set -euo pipefail

UPDATER_VERSION="1.3.0"
REPO_OWNER="lbjlaq"
REPO_NAME="Antigravity-Manager"
APP_CMD_NAME="antigravity-tools"

CHECK_ONLY=false
SHOW_CHANGELOG=false
SILENT=false
PROXY_URL=""
REQUESTED_FORMAT="auto"

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

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

print_usage() {
    cat <<USAGE
Antigravity Tools Updater v$UPDATER_VERSION (Linux)

Usage: $0 [OPTIONS]

Options:
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
    else
        echo "Not installed"
    fi
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
        echo "ERROR: Failed to fetch release information from GitHub API." >&2
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

    print_msg "Downloading: $DOWNLOAD_NAME"
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

    write_log "INFO" "Downloaded asset: $DOWNLOAD_NAME"
}

stop_running_app() {
    pkill -f "Antigravity Tools" 2>/dev/null || true
    pkill -f "antigravity-tools" 2>/dev/null || true
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

    print_msg "Installed AppImage: $target_path"
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_msg "Note: $install_dir is not in PATH. Add it to run 'antigravity-tools' directly."
    fi

    write_log "INFO" "Installed AppImage to $target_path"
}

install_asset() {
    stop_running_app

    case "$DOWNLOAD_NAME" in
        *.deb)
            print_msg "Installing .deb package..."
            install_deb_package
            ;;
        *.rpm)
            print_msg "Installing .rpm package..."
            install_rpm_package
            ;;
        *.AppImage)
            print_msg "Installing AppImage..."
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

    validate_format
    detect_arch
    detect_install_format

    print_msg "Antigravity Tools Updater v$UPDATER_VERSION (Linux)"
    print_msg "Architecture: $ARCH_LABEL"
    print_msg "Preferred package format: $ASSET_FORMAT"

    CURRENT_VERSION=$(get_current_version)
    print_msg "Current version: $CURRENT_VERSION"
    write_log "INFO" "Current version: $CURRENT_VERSION"

    fetch_release_info
    print_msg "Latest version: $LATEST_VERSION"
    write_log "INFO" "Latest version: $LATEST_VERSION"

    if [[ "$SHOW_CHANGELOG" == true ]]; then
        print_msg ""
        print_msg "Release notes:"
        print_msg "-------------------------"
        if [[ -n "$RELEASE_BODY" ]]; then
            print_msg "$RELEASE_BODY"
        else
            print_msg "No changelog available."
        fi
        print_msg "-------------------------"
        print_msg ""
    fi

    if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
        print_msg "Already up to date."
        write_log "INFO" "Already on latest version"
        exit 0
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        echo "Update available: $CURRENT_VERSION -> $LATEST_VERSION"
        write_log "INFO" "Check-only mode: update available"
        exit 0
    fi

    select_asset
    print_msg "Selected asset: $DOWNLOAD_NAME"
    write_log "INFO" "Selected asset: $DOWNLOAD_NAME"

    download_asset
    install_asset

    print_msg ""
    print_msg "Update completed successfully."
    print_msg "Old version: $CURRENT_VERSION"
    print_msg "New version: $LATEST_VERSION"

    write_log "INFO" "Update completed: $CURRENT_VERSION -> $LATEST_VERSION"
}

main "$@"
