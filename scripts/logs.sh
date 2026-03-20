#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/lib/common.sh"

LINES=50
FOLLOW=false
DOCKER_LOGS=false

print_usage() {
    echo "Usage: ./ckserver.sh logs [--docker] [-f|--follow] [--lines N|N]"
}

require_positive_integer() {
    local value="$1"

    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--follow)
            FOLLOW=true
            ;;
        --docker)
            DOCKER_LOGS=true
            ;;
        --lines)
            if [ $# -lt 2 ]; then
                print_error "Error: --lines requires a positive integer argument."
                print_usage
                exit 1
            fi
            if ! require_positive_integer "$2"; then
                print_error "Error: line count must be a positive integer."
                exit 1
            fi
            LINES="$2"
            shift
            ;;
        *)
            if ! require_positive_integer "$1"; then
                print_error "Error: unsupported logs argument '$1'."
                print_usage
                exit 1
            fi
            LINES="$1"
            ;;
    esac
    shift
done

if [ "$DOCKER_LOGS" = "true" ]; then
    if [ "$FOLLOW" = "true" ]; then
        run_compose logs -f
    else
        run_compose logs --tail="$LINES"
    fi
else
    LOG_FILE="$(latest_game_log)"
    
    if [ -n "$LOG_FILE" ]; then
        if [ "$FOLLOW" = "true" ]; then
            tail -f "$LOG_FILE"
        else
            tail -n "$LINES" "$LOG_FILE"
        fi
    else
        echo "Game logs directory not found: $GAME_LOG_DIR"
        echo "Server may not have started yet. Try: ./ckserver.sh logs --docker"
    fi
fi
