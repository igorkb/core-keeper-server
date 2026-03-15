#!/bin/bash

COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$COMMON_LIB_DIR/../.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
ENV_FILE="$PROJECT_ROOT/.env"
DATA_DIR="$PROJECT_ROOT/data"
SERVER_FILES_DIR="$DATA_DIR/server-files"
WORLD_DATA_DIR="$DATA_DIR/world-data"
GAME_LOG_DIR="$SERVER_FILES_DIR/logs"
BACKUPS_DIR="$PROJECT_ROOT/backups"
PROJECT_LOG_DIR="$PROJECT_ROOT/logs"
SERVER_CONFIG_FILE="$WORLD_DATA_DIR/ServerConfig.json"
SERVICE_NAME="core-keeper"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    local title="$1"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}     ${title}${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_error() {
    echo -e "${RED}$*${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}$*${NC}"
}

print_success() {
    echo -e "${GREEN}$*${NC}"
}

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

strip_double_quotes() {
    local value="$1"

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
        value="${value:1:${#value}-2}"
    fi

    printf '%s' "$value"
}

get_env_value() {
    local key="$1"

    [ -f "$ENV_FILE" ] || return 1

    awk -v key="$key" '
        $0 ~ "^[[:space:]]*" key "=" {
            sub(/^[[:space:]]*[^=]*=/, "", $0)
            print
            exit
        }
    ' "$ENV_FILE"
}

get_trimmed_env_value() {
    local key="$1"
    local value

    value="$(get_env_value "$key" 2>/dev/null || true)"
    value="$(trim "$value")"
    strip_double_quotes "$value"
}

get_effective_max_players() {
    local value

    value="$(get_trimmed_env_value MAX_PLAYERS)"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s' "$value"
        return
    fi

    if [ -f "$SERVER_CONFIG_FILE" ]; then
        value="$(grep -o '"maxNumberPlayers":[[:space:]]*[0-9]\+' "$SERVER_CONFIG_FILE" 2>/dev/null | grep -o '[0-9]\+' | head -1 || true)"
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            printf '%s' "$value"
            return
        fi
    fi

    printf '8'
}

get_server_port() {
    get_trimmed_env_value SERVER_PORT
}

get_connection_mode_summary() {
    local server_port

    server_port="$(get_server_port)"
    if [ -n "$server_port" ]; then
        printf 'Direct (port %s - requires port forwarding)' "$server_port"
    else
        printf 'Steam (SDR - no port forwarding needed)'
    fi
}

ensure_project_dirs() {
    mkdir -p "$SERVER_FILES_DIR" "$WORLD_DATA_DIR" "$BACKUPS_DIR" "$PROJECT_LOG_DIR"
}

require_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        print_error "Error: .env file not found. Copy .env.example to .env and configure it."
        exit 1
    fi
}

run_compose() {
    local compose_args=(-f "$COMPOSE_FILE")
    local server_port
    server_port="$(get_server_port)"
    if [ -n "$server_port" ]; then
        compose_args+=(-f "$PROJECT_ROOT/docker-compose.direct-connect.yml" -e "SERVER_PORT=$server_port")
    fi
    docker compose "${compose_args[@]}" --env-file "$PROJECT_ROOT/.compose.env" "$@"
}

is_service_running() {
    run_compose ps --status running --services 2>/dev/null | grep -Fxq "$SERVICE_NAME"
}

latest_game_log() {
    if [ -d "$GAME_LOG_DIR" ]; then
        ls -1t "$GAME_LOG_DIR"/*.log 2>/dev/null | head -1
    fi
}

latest_backup_file() {
    if [ -d "$BACKUPS_DIR" ]; then
        ls -1t "$BACKUPS_DIR"/*.tar.gz 2>/dev/null | head -1
    fi
}

file_date() {
    local path="$1"

    stat -c %y "$path" 2>/dev/null | cut -d' ' -f1
}

file_mtime_epoch() {
    local path="$1"

    stat -c %Y "$path" 2>/dev/null
}

get_connected_players() {
    local log_file max_players joins leaves active

    max_players="$(get_effective_max_players)"
    log_file="$(latest_game_log)"

    if [ -z "$log_file" ]; then
        printf '0/%s' "$max_players"
        return
    fi

    joins=$(grep -Eci 'Player.*(joined|connected)' "$log_file" 2>/dev/null || true)
    leaves=$(grep -Eci 'Player.*(left|disconnect|disconnected)' "$log_file" 2>/dev/null || true)
    active=$((joins - leaves))

    if [ "$active" -lt 0 ]; then
        active=0
    fi

    printf '%s/%s' "$active" "$max_players"
}
