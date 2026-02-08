#!/bin/bash
# shellcheck disable=SC2034

# Antigravity Tools Updater - macOS Version
# Supports 51 languages with automatic system language detection
# Version 1.4.3 - Security Enhanced

set -eo pipefail

# Version
UPDATER_VERSION="1.4.3"

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
EXPECTED_BUNDLE_ID="com.lbjlaq.antigravity-tools"  # Expected bundle identifier for signature verification

# Script directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALES_DIR="$SCRIPT_DIR/locales"

# If running from .app bundle, look for locales alongside the .app bundle
if [[ "$SCRIPT_DIR" == *".app/Contents/Resources"* ]]; then
    APP_BUNDLE_DIR="${SCRIPT_DIR%%.app/*}"
    APP_BUNDLE_DIR="$(dirname "${APP_BUNDLE_DIR}.app")"
    LOCALES_DIR="$APP_BUNDLE_DIR/locales"
fi

# Logging and backup directories
LOG_DIR="$HOME/Library/Application Support/AntigravityUpdater"
LOG_FILE="$LOG_DIR/updater.log"
BACKUP_DIR="$LOG_DIR/backups"

# Secure temp directory with random suffix
TEMP_DIR=$(mktemp -d -t "AntigravityUpdater.XXXXXXXX")

# Cleanup on exit (normal or unexpected)
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

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

# Default messages (overridden by locale files via source)
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
MSG_OPENING_APP="🚀 Opening application..."  # used by locale files
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
MSG_CODESIGN_WARN="⚠️  Warning: Code signature not verified"  # used by locale files
LANG_NAME="English"
LANG_CODE="en"  # used by locale files

#region Logging Functions

init_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
    fi
}

write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true

    # Rotate log if > 1MB
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo "0")
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
    local resolved_path
    resolved_path=$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")
    local resolved_base
    resolved_base=$(cd "$base_path" 2>/dev/null && pwd)

    # Check if path is exactly base or starts with base/
    if [[ "$resolved_path" == "$resolved_base" ]] || [[ "$resolved_path" == "$resolved_base"/* ]]; then
        return 0
    fi

    return 1
}

# Compare versions (returns 0 if $1 > $2)
version_gt() {
    python3 -c "import sys; v1=[int(x) for x in sys.argv[1].split('-')[0].split('.')]; v2=[int(x) for x in sys.argv[2].split('-')[0].split('.')]; print(1 if v1 > v2 else 0)" "$1" "$2" 2>/dev/null | grep -q 1
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
        # First, verify the signature is valid
        if ! codesign --verify --deep --strict "$app_path" 2>/dev/null; then
            write_log "ERROR" "Code signature verification failed: signature is invalid"
            return 1
        fi

        # Extract the bundle identifier from the app
        local bundle_id
        bundle_id=$(defaults read "$app_path/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "")

        if [[ -z "$bundle_id" ]]; then
            write_log "ERROR" "Could not read bundle identifier from app"
            return 1
        fi

        # Verify bundle identifier matches expected value (mandatory check)
        if [[ -z "$EXPECTED_BUNDLE_ID" ]]; then
            write_log "ERROR" "EXPECTED_BUNDLE_ID not configured - cannot verify app identity"
            return 1
        fi

        if [[ "$bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
            write_log "ERROR" "Bundle identifier mismatch: expected '$EXPECTED_BUNDLE_ID', got '$bundle_id'"
            return 1
        fi
        write_log "INFO" "Bundle identifier verified: $bundle_id"

        # Extract and log the Team ID for additional verification
        local team_id
        team_id=$(codesign -dv "$app_path" 2>&1 | grep "TeamIdentifier" | cut -d= -f2 | xargs 2>/dev/null || echo "")
        if [[ -n "$team_id" ]]; then
            write_log "INFO" "App signed by Team ID: $team_id"
        else
            write_log "WARN" "Could not extract Team ID from signature"
        fi

        return 0
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

    local file_size
    file_size=$(stat -f%z "$file_path" 2>/dev/null || echo "0")
    if [[ $file_size -eq 0 ]]; then
        write_log "ERROR" "Downloaded file is empty: $file_path"
        return 1
    fi

    # Verify hash if provided
    if [[ -n "$expected_hash" ]]; then
        if [[ "$SILENT" != true ]]; then
            echo -e "${BLUE}$MSG_HASH_VERIFY${NC}"
        fi

        local actual_hash
        actual_hash=$(get_file_hash "$file_path")

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

    local timestamp
    timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_name="backup_$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"

    if ditto "$app_path" "$backup_path" 2>/dev/null; then
        # Keep only the latest 3 backups (names are timestamped, so lexical order is chronological).
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
        return 0
    fi

    write_log "ERROR" "Backup failed"
    return 1
}

restore_backup() {
    local backups=()
    local backup
    local latest_backup=""
    shopt -s nullglob
    for backup in "$BACKUP_DIR"/backup_*; do
        [[ -d "$backup" ]] || continue
        backups+=("$backup")
    done
    shopt -u nullglob

    if [[ ${#backups[@]} -gt 0 ]]; then
        local last_idx=$(( ${#backups[@]} - 1 ))
        latest_backup="${backups[$last_idx]}"
    fi

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
    if ditto "$latest_backup" "$APP_PATH" 2>/dev/null; then
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
        # shellcheck disable=SC1090
        source "$lang_file"
        write_log "INFO" "Language loaded: $lang_code"
        return 0
    fi

    # Fallback to English
    local en_file="$LOCALES_DIR/en.sh"
    if validate_path "$en_file" "$LOCALES_DIR" && [[ -f "$en_file" ]]; then
        # shellcheck disable=SC1090
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
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}Error: --proxy requires a URL value${NC}"
                exit 1
            fi
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
    echo "║         $MSG_TITLE v$UPDATER_VERSION              ║"
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
    exit 1
fi

# Get latest version from GitHub
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_CHECKING_LATEST${NC}"
fi

# Build curl command with optional proxy
declare -a CURL_OPTS=("-s" "-f" "-A" "AntigravityUpdater/$UPDATER_VERSION")
if [[ -n "$PROXY_URL" ]]; then
    CURL_OPTS+=("--proxy" "$PROXY_URL")
    write_log "INFO" "Using proxy: $PROXY_URL"
fi

if ! RELEASE_INFO=$(curl "${CURL_OPTS[@]}" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" 2>/dev/null); then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_API_ERROR${NC}"
    fi
    write_log "ERROR" "GitHub API request failed"
    exit 1
fi

if [[ -z "$RELEASE_INFO" ]] || [[ "$RELEASE_INFO" == *"rate limit"* ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_API_ERROR${NC}"
    fi
    write_log "ERROR" "GitHub API error"
    exit 1
fi

# Optimization: Combine JSON parsing into a single python process to reduce startup overhead.
# Uses shlex.quote to safely escape strings for eval.
# Reset parsed values to avoid reusing any pre-existing environment or stale script values.
unset LATEST_VERSION RELEASE_BODY
PARSE_ASSIGNMENTS="$(echo "$RELEASE_INFO" | python3 -c "import sys, json, shlex; data=json.load(sys.stdin); print(f'LATEST_VERSION={shlex.quote(data.get(\"tag_name\", \"\").lstrip(\"v\"))}'); print(f'RELEASE_BODY={shlex.quote(data.get(\"body\", \"\"))}')" 2>/dev/null || echo "")"

if [[ -z "$PARSE_ASSIGNMENTS" ]]; then
    write_log "ERROR" "Failed to parse release information from GitHub response"
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}Error: Could not parse release information.${NC}"
    fi
    exit 1
fi

eval "$PARSE_ASSIGNMENTS"

if [[ -z "$LATEST_VERSION" ]]; then
    write_log "ERROR" "Could not parse latest version from GitHub response"
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}Error: Could not parse latest version.${NC}"
    fi
    exit 1
fi

# Validate that LATEST_VERSION matches an expected version pattern (e.g., 1.2.3 or 1.2.3-beta)
if ! [[ "$LATEST_VERSION" =~ ^[0-9]+(\.[0-9]+)*(-[A-Za-z0-9._-]+)?$ ]]; then
    write_log "ERROR" "Parsed latest version has unexpected format: '$LATEST_VERSION'"
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}Error: Parsed latest version has unexpected format.${NC}"
    fi
    exit 1
fi

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
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]] || ! version_gt "$LATEST_VERSION" "$CURRENT_VERSION"; then
    if [[ "$SILENT" != true ]]; then
        echo ""
        echo -e "${GREEN}$MSG_ALREADY_LATEST${NC}"
    fi
    write_log "INFO" "Already on latest version (Current: $CURRENT_VERSION, Latest: $LATEST_VERSION)"
    exit 0
fi

# Check-only mode
if [[ "$CHECK_ONLY" == true ]]; then
    echo ""
    echo -e "${YELLOW}Update available: $CURRENT_VERSION -> $LATEST_VERSION${NC}"
    write_log "INFO" "Check-only mode: update available"
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
    exit 1
fi

# Mount DMG
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_MOUNTING${NC}"
fi

MOUNT_OUTPUT=$(hdiutil attach "$DMG_PATH" -nobrowse -quiet 2>&1)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep "/Volumes/" | sed 's|.*\(/Volumes/.*\)|\1|')

if [[ -z "$MOUNT_POINT" ]]; then
    shopt -s nullglob
    volume_candidates=(/Volumes/*Antigravity*)
    shopt -u nullglob
    if [[ ${#volume_candidates[@]} -gt 0 ]]; then
        MOUNT_POINT="${volume_candidates[0]}"
    fi
fi

if [[ -z "$MOUNT_POINT" ]] || [[ ! -d "$MOUNT_POINT" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_MOUNT_FAILED${NC}"
    fi
    write_log "ERROR" "Failed to mount DMG"
    exit 1
fi

if [[ "$SILENT" != true ]]; then
    echo -e "${GREEN}$MSG_MOUNTED: $MOUNT_POINT${NC}"
fi

SOURCE_APP="$MOUNT_POINT/$APP_NAME.app"

if [[ ! -d "$SOURCE_APP" ]]; then
    SOURCE_APP=$(find "$MOUNT_POINT" -maxdepth 1 -name "*.app" | head -1)
fi

# Security: Ensure source is a real directory, not a symlink
if [[ -L "$SOURCE_APP" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}Error: Source application is a symlink${NC}"
    fi
    write_log "ERROR" "Source application is a symlink: $SOURCE_APP"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
fi

if [[ -z "$SOURCE_APP" ]] || [[ ! -d "$SOURCE_APP" ]]; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}$MSG_APP_NOT_FOUND${NC}"
    fi
    write_log "ERROR" "Application not found in DMG"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
fi

# Verify code signature
if [[ "$SILENT" != true ]]; then
    echo -e "${BLUE}$MSG_CODESIGN_CHECK${NC}"
fi

if verify_codesign "$SOURCE_APP"; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${GREEN}$MSG_CODESIGN_OK${NC}"
    fi
    write_log "INFO" "Code signature valid"
else
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}Code signature verification failed!${NC}"
    fi
    write_log "ERROR" "Code signature verification failed"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
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

# Use ditto for safer app bundle copying (preserves resource forks/permissions)
if ditto "$SOURCE_APP" "$APP_PATH"; then
    if [[ "$SILENT" != true ]]; then
        echo -e "${GREEN}$MSG_COPIED${NC}"
    fi
    write_log "INFO" "Application installed to: $APP_PATH"
else
    if [[ "$SILENT" != true ]]; then
        echo -e "${RED}Failed to copy application${NC}"
    fi
    write_log "ERROR" "Failed to copy application with ditto"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
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

# Success message
if [[ "$SILENT" != true ]]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         $MSG_UPDATE_SUCCESS                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "   $MSG_OLD_VERSION: ${YELLOW}$CURRENT_VERSION${NC}"
    echo -e "   $MSG_NEW_VERSION_LABEL: ${GREEN}$LATEST_VERSION${NC}"
    echo ""
fi

write_log "INFO" "Update completed: $CURRENT_VERSION -> $LATEST_VERSION"

#endregion
