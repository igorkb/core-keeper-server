#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$(dirname "$SCRIPT_DIR")/docker-compose.yml"
DATA_DIR="$(dirname "$SCRIPT_DIR")/data"
BACKUPS_DIR="$(dirname "$SCRIPT_DIR")/backups"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     Core Keeper Server Status${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

CONTAINER_STATUS=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

if [ "$CONTAINER_STATUS" = "running" ]; then
    echo -e "Container:     ${GREEN}Running${NC}"
else
    echo -e "Container:     ${RED}Stopped${NC}"
fi

if [ -f "$DATA_DIR/server-files/GameID.txt" ]; then
    GAME_ID=$(cat "$DATA_DIR/server-files/GameID.txt" 2>/dev/null || echo "N/A")
    echo -e "Game ID:       $GAME_ID"
else
    echo -e "Game ID:       ${YELLOW}Not generated yet${NC}"
fi

if [ -d "$DATA_DIR/world-data" ]; then
    WORLD_SIZE=$(du -sh "$DATA_DIR/world-data" 2>/dev/null | cut -f1 || echo "0")
    echo -e "World Size:    $WORLD_SIZE"
else
    echo -e "World Size:    ${YELLOW}No data${NC}"
fi

if [ -d "$BACKUPS_DIR" ] && [ "$(ls -A "$BACKUPS_DIR" 2>/dev/null)" ]; then
    LATEST_BACKUP=$(ls -t "$BACKUPS_DIR"/*.tar.gz 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$LATEST_BACKUP" 2>/dev/null)
        BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
        BACKUP_AGE=$(echo "$(date +%s) - $(stat -c %Y "$LATEST_BACKUP" 2>/dev/null || echo $(date +%s))" | bc 2>/dev/null || echo "0")
        BACKUP_HOURS=$((BACKUP_AGE / 3600))
        
        echo -e "Last Backup:   $BACKUP_DATE ($BACKUP_SIZE)"
        echo -e "Backup Age:    ${BACKUP_HOURS} hours ago"
    fi
else
    echo -e "Last Backup:   ${YELLOW}None${NC}"
fi

echo ""

if [ "$CONTAINER_STATUS" = "running" ]; then
    echo -e "${GREEN}Server is running and ready for connections!${NC}"
    
    if [ -z "${SERVER_PORT:-}" ]; then
        echo ""
        echo "Connection: Steam (SDR - no port forwarding needed)"
    else
        echo ""
        echo "Connection: Direct (port $SERVER_PORT - requires port forwarding)"
    fi
else
    echo -e "${YELLOW}Server is not running.${NC}"
    echo "Start with: ./server.sh start"
fi
