#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$(dirname "$SCRIPT_DIR")/docker-compose.yml"
DATA_DIR="$(dirname "$SCRIPT_DIR")/data"

LINES=50
FOLLOW=false
DOCKER_LOGS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--follow)
            FOLLOW=true
            ;;
        --docker)
            DOCKER_LOGS=true
            ;;
        --lines)
            LINES="$2"
            shift
            ;;
        *)
            LINES="$1"
            ;;
    esac
    shift
done

cd "$(dirname "$SCRIPT_DIR")"

if [ "$DOCKER_LOGS" = "true" ]; then
    if [ "$FOLLOW" = "true" ]; then
        docker compose -f "$COMPOSE_FILE" logs -f
    else
        docker compose -f "$COMPOSE_FILE" logs --tail="$LINES"
    fi
else
    LOG_DIR="$DATA_DIR/server-files/logs"
    
    if [ -d "$LOG_DIR" ] && [ "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
        LOG_FILE=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        
        if [ -n "$LOG_FILE" ]; then
            if [ "$FOLLOW" = "true" ]; then
                tail -f "$LOG_FILE"
            else
                tail -n "$LINES" "$LOG_FILE"
            fi
        else
            echo "No log files found in $LOG_DIR"
        fi
    else
        echo "Game logs directory not found: $LOG_DIR"
        echo "Server may not have started yet. Try: ./server.sh logs --docker"
    fi
fi
