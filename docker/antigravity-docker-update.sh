#!/usr/bin/env bash
# shellcheck disable=SC2034

# Antigravity Tools Docker Updater
# Pulls and optionally restarts a Docker deployment with the latest image tag.
# Supports 51 languages with shared locale files.

set -euo pipefail

UPDATER_VERSION="1.7.0"
REPO_OWNER="lbjlaq"
REPO_NAME="Antigravity-Manager"
DEFAULT_IMAGE_REPO="lbjlaq/antigravity-manager"
DEFAULT_CONTAINER_NAME="antigravity-manager"

CHECK_ONLY=false
SHOW_CHANGELOG=false
SILENT=false
RESTART_CONTAINER=false
PROXY_URL=""
IMAGE_REPO="$DEFAULT_IMAGE_REPO"
CONTAINER_NAME="$DEFAULT_CONTAINER_NAME"
TAG_OVERRIDE=""
CHANGE_LANGUAGE=false
RESET_LANG=false
ENABLE_AUTO_UPDATE=false
DISABLE_AUTO_UPDATE=false
AUTO_UPDATE_FREQUENCY=""
GITHUB_TOKEN=""
TARGET_VERSION=""
JSON_OUTPUT=false
SELF_UPDATE=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALES_DIR="$SCRIPT_DIR/../locales"
LANG_PREF_FILE="$HOME/.antigravity_updater_lang_docker"
SELECTED_LANG="en"

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$XDG_STATE_HOME/AntigravityUpdater"
LOG_FILE="$LOG_DIR/docker-updater.log"
HISTORY_FILE="$LOG_DIR/update-history.json"
CACHE_FILE="$LOG_DIR/download-cache.json"
HOOKS_DIR="$LOG_DIR/hooks"
TEMP_DIR="$(mktemp -d -t antigravity-docker-updater.XXXXXXXX)"

LATEST_RELEASE_TAG=""
LATEST_RELEASE_BODY=""
TARGET_TAG=""
TARGET_IMAGE=""
CURRENT_IMAGE="Not installed"
CONTAINER_EXISTS=false

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
MSG_DOWNLOAD_FAILED="Download failed!"
MSG_DOWNLOAD_COMPLETE="Download complete"
MSG_UPDATE_SUCCESS="UPDATE COMPLETED SUCCESSFULLY!"
MSG_OLD_VERSION="Old version"
MSG_NEW_VERSION_LABEL="New version"
MSG_API_ERROR="Cannot access GitHub API"
MSG_SELECT_LANGUAGE="Select language"
LANG_NAME="English"

MSG_TARGET_IMAGE="Target image"
MSG_CONTAINER_NOT_FOUND="Container not found"
MSG_CONTAINER_UP_TO_DATE="Container is already up to date"
MSG_CONTAINER_RESTARTED="Container restarted successfully"
MSG_IMAGE_PULLED="Image pulled"
MSG_PULLING_IMAGE="Pulling image"
MSG_STOPPING_CONTAINER="Stopping container"
MSG_REMOVING_CONTAINER="Removing container"
MSG_STARTING_CONTAINER="Starting container with new image"
MSG_DOCKER_NOT_INSTALLED="Docker is not installed"
MSG_DOCKER_DAEMON_UNAVAILABLE="Docker daemon is not reachable"
MSG_NO_ACTION="No action needed"
MSG_UPDATE_AVAILABLE="Update available"
MSG_AUTO_UPDATE_ENABLED="Automatic updates enabled"
MSG_AUTO_UPDATE_DISABLED="Automatic updates disabled"
MSG_AUTO_UPDATE_INVALID_FREQ="Invalid auto-update frequency"
MSG_AUTO_UPDATE_SUPPORTED="Supported values: hourly, every3hours, every6hours, daily, weekly, monthly"
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
Antigravity Tools Docker Updater v$UPDATER_VERSION

Usage: $0 [OPTIONS]

Options:
  --lang, -l                   Change language
  --reset-lang                 Reset language preference
  --check-only                 Check for updates only
  --changelog                  Show release notes before pulling image
  --restart-container          Restart existing container with new image
  --container-name NAME        Container name (default: $DEFAULT_CONTAINER_NAME)
  --image REPO                 Docker image repo (default: $DEFAULT_IMAGE_REPO)
  --tag TAG                    Override tag (default: latest GitHub release tag)
  --proxy URL                  Proxy for GitHub API requests
  --silent                     Run with minimal output
  --rollback                   (N/A for Docker)
  --token TOKEN                GitHub API token (or set GITHUB_TOKEN env var)
  --version TAG                Target a specific release version
  --json                       Output version info as JSON
  --self-update                Update the updater itself
  --history                    Show update history
  --enable-auto-update          Enable automatic update checks
  --disable-auto-update         Disable automatic update checks
  --auto-update-frequency VALUE hourly | every3hours | every6hours | daily | weekly | monthly
  --help, -h                   Show this help
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_prereqs() {
    local missing=()

    for cmd in curl python3; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        write_log "ERROR" "Missing required command(s): ${missing[*]}"
        echo "ERROR: Missing required command(s): ${missing[*]}" >&2
        exit 1
    fi
}

fetch_latest_release_tag() {
    local curl_cmd
    local release_info

    curl_cmd=(curl -sS -L -A "AntigravityDockerUpdater/$UPDATER_VERSION")

    if [[ -n "$PROXY_URL" ]]; then
        curl_cmd+=(--proxy "$PROXY_URL")
    fi

    if [[ -n "$GITHUB_TOKEN" ]]; then
        curl_cmd+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi

    if [[ -n "$TARGET_VERSION" ]]; then
        local pinned_tag="$TARGET_VERSION"
        [[ "$pinned_tag" =~ ^[0-9] ]] && pinned_tag="v$pinned_tag"
        release_info=$("${curl_cmd[@]}" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$pinned_tag" || true)
        print_msg "$MSG_VERSION_PINNED: $pinned_tag"
    else
        release_info=$("${curl_cmd[@]}" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" || true)
    fi

    if [[ -z "$release_info" ]] || [[ "$release_info" == *"API rate limit exceeded"* ]]; then
        write_log "ERROR" "Failed to fetch latest release from GitHub API"
        echo "ERROR: $MSG_API_ERROR." >&2
        exit 1
    fi

    # Securely parse JSON without eval by separating fields with newlines
    local release_data
    release_data=$(printf '%s' "$release_info" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('tag_name') or ''); print(data.get('body') or '')" 2>/dev/null || true)

    LATEST_RELEASE_TAG=$(printf '%s\n' "$release_data" | head -n1)
    LATEST_RELEASE_BODY=$(printf '%s\n' "$release_data" | tail -n+2)

    if [[ -z "$LATEST_RELEASE_TAG" ]] || [[ "$LATEST_RELEASE_TAG" == "<no value>" ]]; then
        write_log "ERROR" "Could not parse tag_name from GitHub response"
        echo "ERROR: Could not parse latest release tag from GitHub response." >&2
        exit 1
    fi
}

show_changelog() {
    echo ""
    echo "=== Changelog ($TARGET_TAG) ==="

    if [[ -z "$LATEST_RELEASE_BODY" ]]; then
        echo "No release notes available."
        return
    fi

    printf '%s\n' "$LATEST_RELEASE_BODY"
}

normalize_target_tag() {
    if [[ -n "$TAG_OVERRIDE" ]]; then
        if [[ "$TAG_OVERRIDE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            TARGET_TAG="v$TAG_OVERRIDE"
        else
            TARGET_TAG="$TAG_OVERRIDE"
        fi
    else
        TARGET_TAG="$LATEST_RELEASE_TAG"
    fi

    TARGET_IMAGE="$IMAGE_REPO:$TARGET_TAG"
}

ensure_docker() {
    if ! command_exists docker; then
        write_log "ERROR" "Docker CLI not found"
        echo "ERROR: Docker CLI not found. $MSG_DOCKER_NOT_INSTALLED." >&2
        exit 1
    fi
}

inspect_container() {
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -Fx "$CONTAINER_NAME" >/dev/null 2>&1; then
        CONTAINER_EXISTS=true
        CURRENT_IMAGE=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "Unknown")
    else
        CONTAINER_EXISTS=false
        CURRENT_IMAGE="$MSG_NOT_INSTALLED"
    fi
}

is_compose_managed() {
    local compose_project

    compose_project=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$CONTAINER_NAME" 2>/dev/null || true)
    [[ -n "$compose_project" && "$compose_project" != "<no value>" ]]
}

pull_target_image() {
    print_msg "$MSG_PULLING_IMAGE: $TARGET_IMAGE"

    if ! docker pull "$TARGET_IMAGE"; then
        write_log "ERROR" "docker pull failed for $TARGET_IMAGE"
        echo "ERROR: $MSG_DOWNLOAD_FAILED: $TARGET_IMAGE" >&2
        exit 1
    fi

    print_msg "$MSG_DOWNLOAD_COMPLETE"
    write_log "INFO" "Image pulled: $TARGET_IMAGE"
}

generate_recreate_command() {
    local inspect_json
    inspect_json=$(docker inspect "$CONTAINER_NAME")

    INSPECT_JSON="$inspect_json" TARGET_IMAGE="$TARGET_IMAGE" CONTAINER_NAME="$CONTAINER_NAME" python3 <<'PY'
import json
import os
import shlex
import sys

items = json.loads(os.environ["INSPECT_JSON"])
if not items:
    raise SystemExit(1)

data = items[0]
cfg = data.get("Config") or {}
host = data.get("HostConfig") or {}
mounts = data.get("Mounts") or []

container_name = os.environ["CONTAINER_NAME"]
target_image = os.environ["TARGET_IMAGE"]

args = ["docker", "run", "-d", "--name", container_name]

restart = host.get("RestartPolicy") or {}
restart_name = restart.get("Name") or ""
if restart_name:
    if restart_name == "on-failure":
        retry_count = restart.get("MaximumRetryCount") or 0
        if int(retry_count) > 0:
            args.extend(["--restart", f"on-failure:{int(retry_count)}"])
        else:
            args.extend(["--restart", "on-failure"])
    else:
        args.extend(["--restart", restart_name])

network_mode = host.get("NetworkMode")
if network_mode and network_mode not in ("default", "bridge"):
    args.extend(["--network", network_mode])

for env in cfg.get("Env") or []:
    args.extend(["-e", env])

for mount in mounts:
    mount_type = mount.get("Type")
    src = mount.get("Source")
    dst = mount.get("Destination")
    rw = mount.get("RW", True)

    if not dst:
        continue

    if mount_type == "bind" and src:
        spec = f"{src}:{dst}"
        if not rw:
            spec += ":ro"
        args.extend(["-v", spec])
    elif mount_type == "volume":
        vol_name = mount.get("Name")
        if vol_name:
            spec = f"{vol_name}:{dst}"
            if not rw:
                spec += ":ro"
            args.extend(["-v", spec])

for container_port, bindings in (host.get("PortBindings") or {}).items():
    if not bindings:
        args.extend(["-p", container_port])
        continue

    for bind in bindings:
        bind = bind or {}
        host_ip = bind.get("HostIp") or ""
        host_port = bind.get("HostPort") or ""

        mapping = ""
        if host_ip and host_ip not in ("0.0.0.0", "::"):
            mapping += host_ip + ":"
        if host_port:
            mapping += host_port + ":"
        mapping += container_port

        args.extend(["-p", mapping])

for host_entry in host.get("ExtraHosts") or []:
    args.extend(["--add-host", host_entry])

for dns in host.get("Dns") or []:
    args.extend(["--dns", dns])

if host.get("Privileged"):
    args.append("--privileged")

if host.get("ReadonlyRootfs"):
    args.append("--read-only")

if cfg.get("User"):
    args.extend(["--user", cfg["User"]])

if cfg.get("WorkingDir"):
    args.extend(["-w", cfg["WorkingDir"]])

cmd_list = []
cmd = cfg.get("Cmd")
if isinstance(cmd, list):
    cmd_list = cmd
elif isinstance(cmd, str) and cmd:
    cmd_list = [cmd]

entrypoint = cfg.get("Entrypoint")
if isinstance(entrypoint, str) and entrypoint:
    args.extend(["--entrypoint", entrypoint])
elif isinstance(entrypoint, list) and entrypoint:
    args.extend(["--entrypoint", entrypoint[0]])
    if len(entrypoint) > 1:
        cmd_list = entrypoint[1:] + cmd_list

args.append(target_image)
args.extend(cmd_list)

print(shlex.join(args))
PY
}

restart_with_new_image() {
    local run_cmd

    if [[ "$CONTAINER_EXISTS" != true ]]; then
        write_log "WARN" "--restart-container requested but container not found: $CONTAINER_NAME"
        echo "ERROR: Container '$CONTAINER_NAME' was not found." >&2
        exit 1
    fi

    if is_compose_managed; then
        write_log "ERROR" "Container appears to be docker-compose managed: $CONTAINER_NAME"
        echo "ERROR: '$CONTAINER_NAME' appears to be managed by docker compose." >&2
        echo "Run this in your compose directory instead:" >&2
        echo "  docker compose pull && docker compose up -d" >&2
        exit 1
    fi

    print_msg "WARNING: Restarting container copies existing environment variables."
    print_msg "This may override defaults in the new image."
    write_log "WARN" "Container restart requested - environment variables will be copied"

    run_cmd=$(generate_recreate_command)

    if [[ -z "$run_cmd" ]]; then
        write_log "ERROR" "Failed to generate docker run command from container inspect"
        echo "ERROR: Failed to generate recreate command for '$CONTAINER_NAME'." >&2
        exit 1
    fi

    write_log "INFO" "Recreate command generated for $CONTAINER_NAME"

    print_msg "$MSG_STOPPING_CONTAINER: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true

    print_msg "$MSG_REMOVING_CONTAINER: $CONTAINER_NAME"
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

    print_msg "$MSG_STARTING_CONTAINER..."
    if ! eval "$run_cmd" >/dev/null; then
        write_log "ERROR" "Container recreate failed"
        echo "ERROR: Failed to recreate container. Run command manually:" >&2
        echo "$run_cmd" >&2
        exit 1
    fi

    write_log "INFO" "Container restarted with image $TARGET_IMAGE"
}

run_check_only() {
    if ! command_exists docker; then
        echo "$MSG_NOT_INSTALLED. $MSG_LATEST: $TARGET_IMAGE"
        return
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "WARNING: $MSG_DOCKER_DAEMON_UNAVAILABLE."
        echo "$MSG_LATEST: $TARGET_IMAGE"
        return
    fi

    inspect_container

    if [[ "$CONTAINER_EXISTS" == true ]]; then
        if [[ "$CURRENT_IMAGE" == "$TARGET_IMAGE" ]]; then
            echo "$MSG_ALREADY_LATEST: $CURRENT_IMAGE"
        else
            echo "$MSG_OLD_VERSION: $CURRENT_IMAGE"
            echo "$MSG_NEW_VERSION_LABEL: $TARGET_IMAGE"
        fi
    else
        echo "$CONTAINER_NAME: $MSG_NOT_INSTALLED"
        echo "$MSG_LATEST: $TARGET_IMAGE"
    fi
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

run_hook() {
    local hook_name="$1"
    local hook_script="$HOOKS_DIR/${hook_name}.sh"
    if [[ ! -f "$hook_script" ]]; then return 0; fi
    [[ ! -x "$hook_script" ]] && chmod +x "$hook_script" 2>/dev/null || true
    print_msg "$MSG_HOOK_PRE_UPDATE"
    write_log "INFO" "Running hook: $hook_name"
    if ! OLD_VERSION="${CURRENT_IMAGE:-}" NEW_VERSION="${TARGET_IMAGE:-}" PLATFORM="docker" bash "$hook_script"; then
        write_log "ERROR" "Hook failed: $hook_name"
        print_msg "ERROR: $MSG_HOOK_FAILED: $hook_name"
        return 1
    fi
    write_log "INFO" "Hook completed: $hook_name"
    return 0
}

send_notification() {
    local title="$1" message="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" 2>/dev/null || true
        write_log "INFO" "Desktop notification sent"
    fi
}

write_history() {
    local from_ver="$1" to_ver="$2" status="$3" asset="${4:-}"
    local timestamp
    timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
    local entry
    entry=$(python3 -c "
import json, sys
entry = {'timestamp': sys.argv[1], 'from_version': sys.argv[2], 'to_version': sys.argv[3],
         'status': sys.argv[4], 'platform': 'docker', 'asset': sys.argv[5]}
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
    if [[ ! -f "$HISTORY_FILE" ]]; then echo "$MSG_HISTORY_EMPTY"; return; fi
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
cache = {'version': sys.argv[1], 'hash': sys.argv[2], 'platform': 'docker'}
with open(sys.argv[3], 'w') as f: json.dump(cache, f, indent=2)
" "$version" "$hash" "$CACHE_FILE" 2>/dev/null || true
}

output_json() {
    local current="$1" latest="$2" available="$3" asset="${4:-}"
    python3 -c "
import json, sys
data = {'current_version': sys.argv[1], 'latest_version': sys.argv[2],
        'update_available': sys.argv[3] == 'true', 'platform': 'docker', 'asset': sys.argv[4] if len(sys.argv) > 4 else ''}
print(json.dumps(data, indent=2))
" "$current" "$latest" "$available" "$asset" 2>/dev/null
}

self_update() {
    print_msg "$MSG_SELF_UPDATE_CHECKING"
    local self_curl=(curl -sS -L -A "AntigravityUpdater/$UPDATER_VERSION")
    [[ -n "$PROXY_URL" ]] && self_curl+=(--proxy "$PROXY_URL")
    [[ -n "$GITHUB_TOKEN" ]] && self_curl+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    local self_info
    self_info=$("${self_curl[@]}" "https://api.github.com/repos/ercanatay/AntigravityUpdater/releases/latest" 2>/dev/null) || { echo "ERROR: $MSG_API_ERROR" >&2; return 1; }
    local self_ver
    self_ver=$(printf '%s' "$self_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','').lstrip('v'))" 2>/dev/null)
    [[ -z "$self_ver" ]] && return 1

    # Simple version comparison
    if [[ "$self_ver" == "$UPDATER_VERSION" ]]; then
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

    [[ -f "$extract_dir/docker/antigravity-docker-update.sh" ]] && cp "$extract_dir/docker/antigravity-docker-update.sh" "$SCRIPT_DIR/antigravity-docker-update.sh" && chmod +x "$SCRIPT_DIR/antigravity-docker-update.sh"
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
    local service_file="$systemd_user_dir/antigravity-docker-updater.service"
    local timer_file="$systemd_user_dir/antigravity-docker-updater.timer"
    local script_path
    script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

    mkdir -p "$systemd_user_dir"

    if [[ "$DISABLE_AUTO_UPDATE" == true ]]; then
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user disable --now antigravity-docker-updater.timer >/dev/null 2>&1 || true
            systemctl --user daemon-reload >/dev/null 2>&1 || true
        fi
        rm -f "$service_file" "$timer_file"
        print_msg "$MSG_AUTO_UPDATE_DISABLED"
        write_log "INFO" "Docker automatic updates disabled"
        exit 0
    fi

    cat > "$service_file" <<EOF
[Unit]
Description=Antigravity Docker updater automatic update check

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash $script_path --silent
EOF

    cat > "$timer_file" <<EOF
[Unit]
Description=Run Antigravity Docker updater automatic checks

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
    systemctl --user enable --now antigravity-docker-updater.timer

    print_msg "$MSG_AUTO_UPDATE_ENABLED ($frequency)"
    write_log "INFO" "Docker automatic updates enabled with frequency: $frequency"
    exit 0
}

main() {
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
            --restart-container)
                RESTART_CONTAINER=true
                ;;
            --container-name)
                if [[ $# -lt 2 ]] || [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo "ERROR: --container-name requires a value" >&2
                    exit 1
                fi
                CONTAINER_NAME="$2"
                shift
                ;;
            --image)
                if [[ $# -lt 2 ]] || [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo "ERROR: --image requires a value" >&2
                    exit 1
                fi
                IMAGE_REPO="$2"
                shift
                ;;
            --tag)
                if [[ $# -lt 2 ]] || [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo "ERROR: --tag requires a value" >&2
                    exit 1
                fi
                TAG_OVERRIDE="$2"
                shift
                ;;
            --proxy)
                if [[ $# -lt 2 ]] || [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo "ERROR: --proxy requires a value" >&2
                    exit 1
                fi
                PROXY_URL="$2"
                shift
                ;;
            --silent)
                SILENT=true
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
            --token)
                if [[ $# -lt 2 ]]; then echo "ERROR: --token requires a value" >&2; exit 1; fi
                GITHUB_TOKEN="$2"
                shift
                ;;
            --version)
                if [[ $# -lt 2 ]]; then echo "ERROR: --version requires a value" >&2; exit 1; fi
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

    init_logging

    # GITHUB_TOKEN env var fallback
    if [[ -z "$GITHUB_TOKEN" ]] && [[ -n "${GITHUB_TOKEN:-}" ]]; then
        : # already set
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

    require_prereqs

    print_msg "$MSG_CHECKING_LATEST"
    fetch_latest_release_tag
    normalize_target_tag

    write_log "INFO" "=== Docker updater started v$UPDATER_VERSION ==="
    write_log "INFO" "Target image: $TARGET_IMAGE"

    print_msg "$MSG_TITLE Docker Updater v$UPDATER_VERSION"
    print_msg "$LANG_NAME (--lang to change)"
    print_msg "$MSG_LATEST: $TARGET_IMAGE"

    if [[ "$SHOW_CHANGELOG" == true ]]; then
        show_changelog
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        run_check_only
        write_log "INFO" "Check-only completed"
        exit 0
    fi

    # JSON output mode
    if [[ "$JSON_OUTPUT" == true ]]; then
        ensure_docker
        inspect_container
        local update_avail="false"
        if [[ "$CURRENT_IMAGE" != "$TARGET_IMAGE" ]]; then
            update_avail="true"
        fi
        output_json "$CURRENT_IMAGE" "$TARGET_IMAGE" "$update_avail" "$TARGET_TAG"
        exit 0
    fi

    ensure_docker
    inspect_container

    if [[ "$CONTAINER_EXISTS" == true ]]; then
        print_msg "$MSG_CURRENT: $CURRENT_IMAGE"
    else
        print_msg "$CONTAINER_NAME: $MSG_NOT_INSTALLED"
    fi

    if [[ "$CONTAINER_EXISTS" == true ]] && [[ "$CURRENT_IMAGE" == "$TARGET_IMAGE" ]] && [[ "$RESTART_CONTAINER" != true ]]; then
        print_msg "$MSG_ALREADY_LATEST"
        write_log "INFO" "Container already on target image"
        exit 0
    fi

    # Pre-update hook
    run_hook "pre-update" || true

    pull_target_image

    if [[ "$RESTART_CONTAINER" == true ]]; then
        restart_with_new_image
        print_msg "$MSG_NEW_VERSION_LABEL: $TARGET_IMAGE"
        print_msg "$MSG_UPDATE_SUCCESS"
    else
        if [[ "$CONTAINER_EXISTS" == true ]]; then
            print_msg "$MSG_IMAGE_PULLED. To apply update to running container use:"
            print_msg "  $0 --restart-container --container-name $CONTAINER_NAME --image $IMAGE_REPO --tag $TARGET_TAG"
        else
            print_msg "$MSG_IMAGE_PULLED. You can start a new container with your preferred docker run / compose setup."
        fi
    fi

    # Post-update hook
    run_hook "post-update" || true

    # Write update history
    write_history "$CURRENT_IMAGE" "$TARGET_IMAGE" "success" "$TARGET_TAG"

    # Update download cache
    update_download_cache "$TARGET_TAG" ""

    # Send desktop notification
    send_notification "$MSG_TITLE" "$MSG_UPDATE_SUCCESS: $TARGET_IMAGE"

    write_log "INFO" "Docker updater completed"
}

main "$@"
