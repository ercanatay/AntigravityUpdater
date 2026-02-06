#!/bin/bash

# Antigravity Tools Updater - macOS Version
# Supports 51 languages with automatic system language detection
# Version 1.4.2 - Security Enhanced

set -e

# Version
UPDATER_VERSION="1.4.2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Settings
REPO_OWNER="lbjlaq"
REPO_NAME="Antigravity-Manager"
APP_NAME="Antigravity Tools"
APP_PATH="/Applications/Antigravity Tools.app"

# Script directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALES_DIR="$SCRIPT_DIR/locales"

# If running from .app bundle, adjust path
if [[ "$SCRIPT_DIR" == *".app/Contents/Resources"* ]]; then
    LOCALES_DIR="$SCRIPT_DIR/locales"
fi

# Logging and backup directories
LOG_DIR="$HOME/Library/Application Support/AntigravityUpdater"
LOG_FILE="$LOG_DIR/updater.log"
BACKUP_DIR="$LOG_DIR/backups"

# Secure temp directory with random suffix
TEMP_DIR=$(mktemp -d -t "AntigravityUpdater.XXXXXXXX")

# Language preference file
LANG_PREF_FILE="$HOME/.antigravity_updater_lang"

# Command line flags
CHECK_ONLY=false
SHOW_CHANGELOG=false
ROLLBACK=false
SILENT=false
NO_BACKUP=false
PROXY_URL=""

# Available languages (51 total)
declare -a LANG_CODES=("en" "tr" "de" "fr" "es" "it" "pt" "ru" "zh" "zh-TW" "ja" "ko" "ar" "nl" "pl" "sv" "no" "da" "fi" "uk" "cs" "hi" "el" "he" "th" "vi" "id" "ms" "hu" "ro" "bg" "hr" "sr" "sk" "sl" "lt" "lv" "et" "ca" "eu" "gl" "is" "fa" "sw" "af" "fil" "bn" "ta" "ur" "mi" "cy")
declare -a LANG_NAMES=("English" "Türkçe" "Deutsch" "Français" "Español" "Italiano" "Português" "Русский" "简体中文" "繁體中文" "日本語" "한국어" "العربية" "Nederlands" "Polski" "Svenska" "Norsk" "Dansk" "Suomi" "Українська" "Čeština" "हिन्दी" "Ελληνικά" "עברית" "ไทย" "Tiếng Việt" "Bahasa Indonesia" "Bahasa Melayu" "Magyar" "Română" "Български" "Hrvatski" "Srpski" "Slovenčina" "Slovenščina" "Lietuvių" "Latviešu" "Eesti" "Català" "Euskara" "Galego" "Íslenska" "فارسی" "Kiswahili" "Afrikaans" "Filipino" "বাংলা" "தமிழ்" "اردو" "Te Reo Māori" "Cymraeg")

# Default messages
MSG_TITLE="🚀 Antigravity Tools Updater"
MSG_CHECKING_VERSION="📦 Checking current version..."
MSG_CURRENT="Current"
MSG_NOT_INSTALLED="Not installed"
MSG_UNKNOWN="Unknown"
MSG_CHECKING_LATEST="🌐 Checking latest version..."
MSG_LATEST="Latest"
MSG_ARCH="Architecture"
MSG_ALREADY_LATEST="✅ You already have the latest version!"
MSG_NEW_VERSION="📥 New version available! Starting download..."
MSG_DOWNLOADING="⬇️  Downloading DMG..."
MSG_DOWNLOAD_FAILED="❌ Download failed!"
MSG_DOWNLOAD_COMPLETE="✅ Download complete"
MSG_MOUNTING="💿 Mounting DMG..."
MSG_MOUNT_FAILED="❌ Failed to mount DMG"
MSG_MOUNTED="✅ DMG mounted"
MSG_CLOSING_APP="🔄 Closing current application..."
MSG_REMOVING_OLD="🗑️  Removing old version..."
MSG_COPYING_NEW="📁 Copying new version..."
MSG_APP_NOT_FOUND="❌ Application not found in DMG"
MSG_COPIED="✅ Application copied"
MSG_REMOVING_QUARANTINE="🔓 Removing quarantine (xattr -cr)..."
MSG_QUARANTINE_REMOVED="✅ Quarantine removed"
MSG_UNMOUNTING="💿 Unmounting DMG..."
MSG_UPDATE_SUCCESS="✅ UPDATE COMPLETED SUCCESSFULLY!"
MSG_OLD_VERSION="Old version"
MSG_NEW_VERSION_LABEL="New version"
MSG_API_ERROR="❌ Cannot access GitHub API"
MSG_SELECT_LANGUAGE="Select language"
MSG_OPENING_APP="🚀 Opening application..."
MSG_BACKUP_CREATED="✅ Backup created"
MSG_BACKUP_FAILED="⚠️  Backup failed"
MSG_ROLLBACK_SUCCESS="✅ Rollback successful"
MSG_ROLLBACK_FAILED="❌ Rollback failed"
MSG_NO_BACKUP="❌ No backup found"
MSG_HASH_VERIFY="🔍 Verifying file integrity..."
MSG_HASH_OK="✅ File integrity verified"
MSG_HASH_FAILED="❌ File integrity check failed!"
MSG_CODESIGN_CHECK="🔐 Checking code signature..."
MSG_CODESIGN_OK="✅ Code signature valid"
MSG_CODESIGN_WARN="⚠️  Warning: Code signature not verified"
LANG_NAME="English"
LANG_CODE="en"

#region Logging Functions

init_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
    fi
}

write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true

    # Rotate log if > 1MB
    if [[ -f "$LOG_FILE" ]]; then
        local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo "0")
        if [[ $size -gt 1048576 ]]; then
            tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
}

#endregion

#region Security Functions

# Validate language code format
validate_lang_code() {
    local lang_code="$1"

    # Only allow valid language codes (2 letters or xx-XX format)
    if [[ ! "$lang_code" =~ ^[a-z]{2}(-[A-Z]{2})?$ ]]; then
        return 1
    fi

    # Check if in allowed list
    for code in "${LANG_CODES[@]}"; do
        if [[ "$code" == "$lang_code" ]]; then
            return 0
        fi
    done

    return 1
}

# Validate path is within allowed directory (prevent path traversal)
validate_path() {
    local path="$1"
    local base_path="$2"

    # Resolve to absolute paths
    local resolved_path=$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")
    local resolved_base=$(cd "$base_path" 2>/dev/null && pwd)

    # Check if path starts with base
    if [[ "$resolved_path" == "$resolved_base"* ]]; then
        return 0
    fi

    return 1
}

# Calculate SHA256 hash
get_file_hash() {
    local file_path="$1"

    if [[ -f "$file_path" ]]; then
        shasum -a 256 "$file_path" 2>/dev/null | awk '{print $1}'
    fi
}

# Verify code signature (macOS specific)
verify_codesign() {
    local app_path="$1"

    if [[ -d "$app_path" ]]; then
        if codesign --verify --deep --strict "$app_path" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Verify downloaded DMG
verify_download() {
    local file_path="$1"
    local expected_hash="$2"

    # Check file exists and has content
    if [[ ! -f "$file_path" ]]; then
        write_log "ERROR" "Downloaded file not found: $file_path"
        return 1
    fi

    local file_size=$(stat -f%z "$file_path" 2>/dev/null || echo "0")
    if [[ $file_size -eq 0 ]]; then
        write_log "ERROR" "Downloaded file is empty: $file_path"
        return 1
    fi

    # Verify hash if provided
    if [[ -n "$expected_hash" ]]; then
        if [[ "$SILENT" != true ]]; then
            echo -e "${BLUE}$MSG_HASH_VERIFY${NC}"
        fi

        local actual_hash=$(get_file_hash "$file_path")

        if [[ "$actual_hash" != "$expected_hash" ]]; then
            if [[ "$SILENT" != true ]]; then
                echo -e "${RED}$MSG_HASH_FAILED${NC}"
            fi
            write_log "ERROR" "Hash mismatch. Expected: $expected_hash, Got: $actual_hash"
            return 1
        fi

        if [[ "$SILENT" != true ]]; then
            echo -e "${GREEN}$MSG_HASH_OK${NC}"
        fi
        write_log "INFO" "Hash verified: $actual_hash"
    fi

    return 0
}

#endregion

#region Backup Functions

create_backup() {
    local app_path="$1"

    if [[ ! -d "$app_path" ]]; then
        return 1
    fi

    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
    fi

    local timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_name="backup_$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"

    if cp -R "$app_path" "$backup_path" 2>/dev/null; then
        # Keep only last 3 backups
        local backups=($(ls -dt "$BACKUP_DIR"/backup_* 2>/dev/null))
        if [[ ${#backups[@]} -gt 3 ]]; then
            for ((i=3; i<${#backups[@]}; i++)); do
                rm -rf "${backups[$i]}"
            done
        fi

        write_log "INFO" "Backup created: $backup_path"
        echo "$backup_path"
        return 0
    fi

    write_log "ERROR" "Backup failed"
    return 1
}

restore_backup() {
    local latest_backup=$(ls -dt "$BACKUP_DIR"/backup_* 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]] || [[ ! -d "$latest_backup" ]]; then
        echo -e "${RED}$MSG_NO_BACKUP${NC}"
        write_log "ERROR" "No backup found for rollback"
        return 1
    fi

    # Remove current version
    if [[ -d "$APP_PATH" ]]; then
        rm -rf "$APP_PATH"
    fi

    # Restore from backup
    if cp -R "$latest_backup" "$APP_PATH" 2>/dev/null; then
        # Remove quarantine
        xattr -cr "$APP_PATH" 2>/dev/null || true

        echo -e "${GREEN}$MSG_ROLLBACK_SUCCESS${NC}"
        write_log "INFO" "Rollback successful from: $latest_backup"
        return 0
    fi

    echo -e "${RED}$MSG_ROLLBACK_FAILED${NC}"
    write_log "ERROR" "Rollback failed"
    return 1
}

#endregion

#region Language Functions

# Load language file with security validation
load_language() {
    local lang_code="$1"

    # Validate language code format
    if ! validate_lang_code "$lang_code"; then
        write_log "WARN" "Invalid language code: $lang_code"
        return 1
    fi

    local lang_file="$LOCALES_DIR/${lang_code}.sh"

    # Security: Verify path is within locales directory
    if ! validate_path "$lang_file" "$LOCALES_DIR"; then
        write_log "ERROR" "Path traversal attempt blocked: $lang_file"
        return 1
    fi

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
        write_log "INFO" "Language loaded: $lang_code"
        return 0
    fi

    # Fallback to English
    local en_file="$LOCALES_DIR/en.sh"
    if validate_path "$en_file" "$LOCALES_DIR" && [[ -f "$en_file" ]]; then
        source "$en_file"
        return 0
    fi

    return 1
}

# Detect system language
detect_system_language() {
    local sys_lang=""

    # Try to get macOS system language
    if command -v defaults &> /dev/null; then
        sys_lang=$(defaults read -g AppleLocale 2>/dev/null | cut -d'_' -f1 || echo "")
    fi

    # Fallback to LANG environment variable
    if [[ -z "$sys_lang" ]]; then
        sys_lang=$(echo "$LANG" | cut -d'_' -f1 | cut -d'.' -f1)
    fi

    # Check if we support this language
    for code in "${LANG_CODES[@]}"; do
        if [[ "$code" == "$sys_lang" ]]; then
            echo "$sys_lang"
            return 0
        fi
    done

    # Default to English
    echo "en"
}

# Show language selection menu
show_language_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     🌍 Select Language / Dil Seçin / 选择语言            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    local cols=3
    local count=${#LANG_CODES[@]}
    local rows=$(( (count + cols - 1) / cols ))

    for ((i=0; i<rows; i++)); do
        for ((j=0; j<cols; j++)); do
            local idx=$((i + j * rows))
            if [[ $idx -lt $count ]]; then
                printf "  ${YELLOW}%2d)${NC} %-12s" $((idx + 1)) "${LANG_NAMES[$idx]}"
            fi
        done
        echo ""
    done

    echo ""
    echo -e "  ${MAGENTA} 0)${NC} Auto-detect / Otomatik"
    echo ""
    echo -n -e "${CYAN}➤ ${NC}"
    read -r choice

    if [[ "$choice" == "0" ]]; then
        SELECTED_LANG=$(detect_system_language)
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$count" ]]; then
        SELECTED_LANG="${LANG_CODES[$((choice - 1))]}"
    else
        SELECTED_LANG="en"
    fi

    # Save preference
    echo "$SELECTED_LANG" > "$LANG_PREF_FILE"

    load_language "$SELECTED_LANG"
}

# Check for saved language preference
check_language_preference() {
    if [[ -f "$LANG_PREF_FILE" ]]; then
        local saved_lang
        saved_lang=$(cat "$LANG_PREF_FILE")
        if load_language "$saved_lang"; then
            SELECTED_LANG="$saved_lang"
            return 0
        fi
    fi
    return 1
}

#endregion

#region Application Functions

# Stop running application with precise matching
stop_application() {
    # More precise process matching
    pkill -x "Antigravity Tools" 2>/dev/null || true
    pkill -x "AntigravityTools" 2>/dev/null || true
    sleep 1
    write_log "INFO" "Application stopped"
}

# Show changelog from release info
show_changelog() {
    local release_body="$1"

    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                      Changelog                           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [[ -n "$release_body" ]]; then
        # Clean markdown formatting
        echo "$release_body" | sed 's/#//g' | sed 's/\*\*//g' | sed 's/\*//g' | sed 's/`//g'
    else
        echo "No changelog available"
    fi

    echo ""
}

# Print usage
print_usage() {
    echo "Antigravity Tools Updater v$UPDATER_VERSION"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --lang, -l          Change language"
    echo "  --reset-lang        Reset language preference"
    echo "  --check-only        Check for updates only (no install)"
    echo "  --changelog         Show changelog before update"
    echo "  --rollback          Rollback to previous version"
    echo "  --silent            Run without prompts"
    echo "  --no-backup         Skip automatic backup"
    echo "  --proxy URL         Use proxy for connections"
    echo "  --help, -h          Show this help"
    echo ""
}

#endregion

#region Main Execution

# Initialize
init_logging
write_log "INFO" "=== Updater started v$UPDATER_VERSION ==="

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang|-l)
            show_language_menu
            shift
            ;;
        --reset-lang)
            rm -f "$LANG_PREF_FILE"
            show_language_menu
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --changelog)
            SHOW_CHANGELOG=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        --silent)
            SILENT=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        --proxy)
            PROXY_URL="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Handle rollback
if [[ "$ROLLBACK" == true ]]; then
    write_log "INFO" "Rollback requested"
    if restore_backup; then
        exit 0
    else
        exit 1
    fi
fi

# Load language preference
if ! check_language_preference; then
    if [[ "$SILENT" != true ]]; then
        show_language_menu
    else
        load_language "en"
    fi
fi

# Architecture detection
if [[ $(uname -m) == "arm64" ]]; then
    ARCH="aarch64"
    ARCH_NAME="Apple Silicon"
else
    ARCH="universal"
    ARCH_NAME="Intel"
fi

# Clear screen for main display (unless silent)
if [[ "$SILENT" != true ]]; then
    clear

    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         $MSG_TITLE v$UPDATER_VERSION"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Show current language
    echo -e "   ${MAGENTA}🌐 $LANG_NAME${NC} (--lang to change)"
    echo ""
fi

# Check current version
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_CHECKING_VERSION${NC}"
fi

if [[ -d "$APP_PATH" ]]; then
    CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "$MSG_UNKNOWN")
    if [[ "$SILENT" != true ]]; then
        echo -e "   $MSG_CURRENT: ${GREEN}$CURRENT_VERSION${NC}"
    fi
    write_log "INFO" "Current version: $CURRENT_VERSION"
else
    CURRENT_VERSION="$MSG_NOT_INSTALLED"
    if [[ "$SILENT" != true ]]; then
        echo -e "   $MSG_CURRENT: ${YELLOW}$CURRENT_VERSION${NC}"
    fi
    write_log "INFO" "Application not installed"
fi

# Python is required for JSON parsing below.
# Kept here so --help and --rollback can still run without python3.
if ! command -v python3 >/dev/null 2>&1; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}Error: python3 is required for update checks.${NC}"
    fi
    write_log "ERROR" "python3 not found"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Get latest version from GitHub
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_CHECKING_LATEST${NC}"
fi

# Build curl command with optional proxy
declare -a CURL_OPTS=("-s" "-A" "AntigravityUpdater/$UPDATER_VERSION")
if [[ -n "$PROXY_URL" ]]; then
    CURL_OPTS+=("--proxy" "$PROXY_URL")
    write_log "INFO" "Using proxy: $PROXY_URL"
fi

RELEASE_INFO=$(curl "${CURL_OPTS[@]}" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")

if [[ -z "$RELEASE_INFO" ]] || [[ "$RELEASE_INFO" == *"rate limit"* ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_API_ERROR${NC}"
    fi
    write_log "ERROR" "GitHub API error"
    rm -rf "$TEMP_DIR"
    exit 1
fi

LATEST_VERSION=$(echo "$RELEASE_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tag_name', '').lstrip('v'))" 2>/dev/null || echo "")
RELEASE_BODY=$(echo "$RELEASE_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin).get('body', ''))" 2>/dev/null || echo "")

if [[ "$SILENT" != true ]]; then
    echo -e "   $MSG_LATEST:    ${GREEN}$LATEST_VERSION${NC}"
    echo -e "   $MSG_ARCH: ${CYAN}$ARCH_NAME ($ARCH)${NC}"
fi
write_log "INFO" "Latest version: $LATEST_VERSION"

# Show changelog if requested
if [[ "$SHOW_CHANGELOG" == true ]] && [[ "$SILENT" != true ]]; then
    show_changelog "$RELEASE_BODY"
    echo -n "Press Enter to continue..."
    read -r
fi

# Check if update is needed
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo ""
        echo -e "${GREEN}$MSG_ALREADY_LATEST${NC}"
    fi
    write_log "INFO" "Already on latest version"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Check-only mode
if [[ "$CHECK_ONLY" == true ]]; then
    echo ""
    echo -e "${YELLOW}Update available: $CURRENT_VERSION -> $LATEST_VERSION${NC}"
    write_log "INFO" "Check-only mode: update available"
    rm -rf "$TEMP_DIR"
    exit 0
fi

if [[ "$SILENT" != true ]]; then
    echo ""
    echo -e "${YELLOW}$MSG_NEW_VERSION${NC}"
fi

# Create backup before update
if [[ "$NO_BACKUP" != true ]] && [[ -d "$APP_PATH" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${BLUE}Creating backup...${NC}"
    fi

    backup_path=$(create_backup "$APP_PATH")
    if [[ -n "$backup_path" ]]; then
        if [[ "$SILENT" != true ]]; then
            echo -e "   ${GREEN}$MSG_BACKUP_CREATED${NC}"
        fi
    else
        if [[ "$SILENT" != true ]]; then
            echo -e "   ${YELLOW}$MSG_BACKUP_FAILED${NC}"
        fi
    fi
fi

# Download DMG
DMG_NAME="Antigravity.Tools_${LATEST_VERSION}_${ARCH}.dmg"
DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/v$LATEST_VERSION/$DMG_NAME"
DMG_PATH="$TEMP_DIR/$DMG_NAME"

if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_DOWNLOADING${NC}"
    echo "   $DOWNLOAD_URL"
fi
write_log "INFO" "Download URL: $DOWNLOAD_URL"

# Build download command with optional proxy
declare -a DOWNLOAD_OPTS=("-L" "--progress-bar" "-o" "$DMG_PATH")
if [[ -n "$PROXY_URL" ]]; then
    DOWNLOAD_OPTS+=("--proxy" "$PROXY_URL")
fi

if ! curl "${DOWNLOAD_OPTS[@]}" "$DOWNLOAD_URL"; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_DOWNLOAD_FAILED${NC}"
    fi
    write_log "ERROR" "Download failed"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if [[ "$SILENT" != true ]]; then
    echo -e "${GREEN}$MSG_DOWNLOAD_COMPLETE${NC}"
fi

# Verify downloaded file
if ! verify_download "$DMG_PATH"; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}File verification failed${NC}"
    fi
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Mount DMG
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_MOUNTING${NC}"
fi

MOUNT_OUTPUT=$(hdiutil attach "$DMG_PATH" -nobrowse -quiet 2>&1)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep "/Volumes/" | sed 's|.*\(/Volumes/.*\)|\1|')

if [[ -z "$MOUNT_POINT" ]]; then
    MOUNT_POINT=$(ls -d /Volumes/*Antigravity* 2>/dev/null | head -1)
fi

if [[ -z "$MOUNT_POINT" ]] || [[ ! -d "$MOUNT_POINT" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_MOUNT_FAILED${NC}"
    fi
    write_log "ERROR" "Failed to mount DMG"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if [[ "$SILENT" != true ]]; then
    echo -e "${GREEN}$MSG_MOUNTED: $MOUNT_POINT${NC}"
fi

# Close running application
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_CLOSING_APP${NC}"
fi
stop_application

# Remove old version
if [[ -d "$APP_PATH" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${BLUE}$MSG_REMOVING_OLD${NC}"
    fi
    rm -rf "$APP_PATH"
fi

# Copy new version
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_COPYING_NEW${NC}"
fi

SOURCE_APP="$MOUNT_POINT/$APP_NAME.app"

if [[ ! -d "$SOURCE_APP" ]]; then
    SOURCE_APP=$(find "$MOUNT_POINT" -maxdepth 1 -name "*.app" | head -1)
fi

if [[ -z "$SOURCE_APP" ]] || [[ ! -d "$SOURCE_APP" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_APP_NOT_FOUND${NC}"
    fi
    write_log "ERROR" "Application not found in DMG"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$TEMP_DIR"
    exit 1
fi

cp -R "$SOURCE_APP" "$APP_PATH"
if [[ "$SILENT" != true ]]; then
    echo -e "${GREEN}$MSG_COPIED${NC}"
fi
write_log "INFO" "Application installed to: $APP_PATH"

# Verify code signature
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_CODESIGN_CHECK${NC}"
fi

if verify_codesign "$APP_PATH"; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${GREEN}$MSG_CODESIGN_OK${NC}"
    fi
    write_log "INFO" "Code signature valid"
else
    if [[ "$SILENT" != true ]]; then
        echo -e "${YELLOW}$MSG_CODESIGN_WARN${NC}"
    fi
    write_log "WARN" "Code signature not verified"
fi

# Remove quarantine
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_REMOVING_QUARANTINE${NC}"
fi
xattr -cr "$APP_PATH"
if [[ "$SILENT" != true ]]; then
    echo -e "${GREEN}$MSG_QUARANTINE_REMOVED${NC}"
fi

# Unmount DMG
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_UNMOUNTING${NC}"
fi
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

# Cleanup
rm -rf "$TEMP_DIR"

# Success message
if [[ "$SILENT" != true ]]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         $MSG_UPDATE_SUCCESS${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "   $MSG_OLD_VERSION: ${YELLOW}$CURRENT_VERSION${NC}"
    echo -e "   $MSG_NEW_VERSION_LABEL: ${GREEN}$LATEST_VERSION${NC}"
    echo ""
fi

write_log "INFO" "Update completed: $CURRENT_VERSION -> $LATEST_VERSION"

#endregion
