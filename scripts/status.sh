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

if [ -f "$SERVER_FILES_DIR/GameID.txt" ]; then
    GAME_ID=$(cat "$SERVER_FILES_DIR/GameID.txt" 2>/dev/null || echo "N/A")
    echo -e "Game ID:       $GAME_ID"
else
    echo -e "Game ID:       ${YELLOW}Not generated yet${NC}"
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
    echo -e "${GREEN}Server is running and ready for connections!${NC}"
    echo ""
    echo "Connection: $(get_connection_mode_summary)"
else
    echo -e "${YELLOW}Server is not running.${NC}"
    echo "Start with: ./server.sh start"
fi
