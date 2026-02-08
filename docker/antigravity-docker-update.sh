#!/usr/bin/env bash
# shellcheck disable=SC2034

# Antigravity Tools Docker Updater
# Pulls and optionally restarts a Docker deployment with the latest image tag.
# Supports 51 languages with shared locale files.

set -euo pipefail

UPDATER_VERSION="1.4.3"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALES_DIR="$SCRIPT_DIR/../locales"
LANG_PREF_FILE="$HOME/.antigravity_updater_lang_docker"
SELECTED_LANG="en"

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$XDG_STATE_HOME/AntigravityUpdater"
LOG_FILE="$LOG_DIR/docker-updater.log"
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

    release_info=$("${curl_cmd[@]}" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" || true)

    if [[ -z "$release_info" ]] || [[ "$release_info" == *"API rate limit exceeded"* ]]; then
        write_log "ERROR" "Failed to fetch latest release from GitHub API"
        echo "ERROR: $MSG_API_ERROR." >&2
        exit 1
    fi

    # Optimization: Combine JSON parsing into a single python process
    # Uses shlex.quote to safely escape strings for eval
    eval "$(printf '%s' "$release_info" | python3 -c "import sys, json, shlex; data=json.load(sys.stdin); print(f'LATEST_RELEASE_TAG={shlex.quote(data.get(\"tag_name\") or \"\")}'); print(f'LATEST_RELEASE_BODY={shlex.quote(data.get(\"body\") or \"\")}')" 2>/dev/null || true)"

    if [[ -z "$LATEST_RELEASE_TAG" ]]; then
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

    write_log "INFO" "Docker updater completed"
}

main "$@"
