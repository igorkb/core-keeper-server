#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

print_header "Core Keeper Server Status"
echo ""

CONTAINER_STATUS="stopped"
if is_service_running; then
    CONTAINER_STATUS="running"
fi

if [ "$CONTAINER_STATUS" = "running" ]; then
    echo -e "Container:     ${GREEN}Running${NC}"
else
    echo -e "Container:     ${RED}Stopped${NC}"
fi

if [ "$CONTAINER_STATUS" = "running" ]; then
    GAME_ID_FILE="$SERVER_FILES_DIR/GameID.txt"
    GAME_ID_READY=false

    if [ -f "$GAME_ID_FILE" ]; then
        CONTAINER_START_EPOCH="$(get_container_start_epoch 2>/dev/null || true)"
        GAME_ID_FILE_EPOCH="$(file_mtime_epoch "$GAME_ID_FILE")"

        if [ -n "$CONTAINER_START_EPOCH" ] && [ -n "$GAME_ID_FILE_EPOCH" ] && \
           [ "$GAME_ID_FILE_EPOCH" -gt "$CONTAINER_START_EPOCH" ]; then
            GAME_ID_READY=true
        fi
    fi

    if [ "$GAME_ID_READY" = true ]; then
        ACTIVE_ID="$(cat "$GAME_ID_FILE" 2>/dev/null || true)"
        CONFIGURED_ID="$(get_configured_game_id)"

        if [ -z "$CONFIGURED_ID" ] || [ "$ACTIVE_ID" = "$CONFIGURED_ID" ]; then
            echo -e "Game ID:       $ACTIVE_ID"
        else
            echo -e "Game ID:       ${YELLOW}${ACTIVE_ID}${NC}"
            echo -e "               ${YELLOW}⚠ Expected '${CONFIGURED_ID}' — server rejected it and generated a random ID${NC}"
        fi
    else
        echo -e "Game ID:       ${YELLOW}Waiting for Game ID...${NC}"
    fi
else
    if [ -f "$SERVER_FILES_DIR/GameID.txt" ]; then
        GAME_ID=$(cat "$SERVER_FILES_DIR/GameID.txt" 2>/dev/null || true)
        echo -e "Game ID:       ${GAME_ID} ${YELLOW}(last run)${NC}"
    else
        echo -e "Game ID:       ${YELLOW}N/A${NC}"
    fi
fi

if [ -d "$WORLD_DATA_DIR" ]; then
    WORLD_SIZE=$(du -sh "$WORLD_DATA_DIR" 2>/dev/null | cut -f1 || echo "0")
    echo -e "World Size:    $WORLD_SIZE"
else
    echo -e "World Size:    ${YELLOW}No data${NC}"
fi

LATEST_BACKUP="$(latest_backup_file)"
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_DATE="$(file_date "$LATEST_BACKUP")"
    BACKUP_EPOCH="$(file_mtime_epoch "$LATEST_BACKUP")"
    if [ -n "$BACKUP_DATE" ] && [ -n "$BACKUP_EPOCH" ]; then
        BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
        NOW_EPOCH=$(date +%s)
        BACKUP_HOURS=$(((NOW_EPOCH - BACKUP_EPOCH) / 3600))
        
        echo -e "Last Backup:   $BACKUP_DATE ($BACKUP_SIZE)"
        echo -e "Backup Age:    ${BACKUP_HOURS} hours ago"
    fi
else
    echo -e "Last Backup:   ${YELLOW}None${NC}"
fi

echo ""

if [ "$CONTAINER_STATUS" = "running" ]; then
    if [ "$GAME_ID_READY" = true ]; then
        echo -e "${GREEN}Server is running and ready for connections!${NC}"
        echo ""
        echo "Connection: $(get_connection_mode_summary)"
    else
        echo -e "${YELLOW}Server is starting up, waiting for Game ID...${NC}"
    fi
else
    echo -e "${YELLOW}Server is not running.${NC}"
    echo "Start with: ./server.sh start"
fi
