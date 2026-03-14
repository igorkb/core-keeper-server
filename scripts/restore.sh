#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
BACKUPS_DIR="$(dirname "$SCRIPT_DIR")/backups"
DATA_DIR="$(dirname "$SCRIPT_DIR")/data"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/restore_$TIMESTAMP.log"
}

BACKUP_FILE=""

if [ -n "${1:-}" ]; then
    if [ -f "$1" ]; then
        BACKUP_FILE="$1"
    elif [ -f "$BACKUPS_DIR/$1" ]; then
        BACKUP_FILE="$BACKUPS_DIR/$1"
    elif [ -f "$BACKUPS_DIR/core-keeper_backup_$1.tar.gz" ]; then
        BACKUP_FILE="$BACKUPS_DIR/core-keeper_backup_$1.tar.gz"
    else
        echo -e "${RED}Backup file not found: $1${NC}"
        exit 1
    fi
else
    echo "Available backups:"
    echo ""
    ls -1t "$BACKUPS_DIR"/*.tar.gz 2>/dev/null | nl -w2 -s") " || {
        echo -e "${RED}No backups found${NC}"
        exit 1
    }
    echo ""
    read -p "Select backup number to restore: " choice
    
    BACKUP_FILE=$(ls -1t "$BACKUPS_DIR"/*.tar.gz 2>/dev/null | sed -n "${choice}p")
    
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}Invalid selection${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}WARNING: This will replace all current world data!${NC}"
echo "Backup to restore: $BACKUP_FILE"
echo ""
read -p "Are you sure? (yes/no): " -r

if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

log "Starting restore from: $BACKUP_FILE"

if docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose.yml" ps --format json 2>/dev/null | grep -q "running"; then
    log "Stopping server for restore..."
    docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose.yml" down
fi

rm -rf "$DATA_DIR/world-data"
mkdir -p "$DATA_DIR/world-data"

tar -xzf "$BACKUP_FILE" -C "$DATA_DIR" 2>&1 | tee -a "$LOG_DIR/restore_$TIMESTAMP.log"

if [ $? -eq 0 ]; then
    if [ -d "$DATA_DIR/world-data/worlds" ]; then
        mv "$DATA_DIR/world-data/worlds"/* "$DATA_DIR/world-data/" 2>/dev/null || true
        rmdir "$DATA_DIR/world-data/worlds" 2>/dev/null || true
    fi
    
    log "Restore completed successfully"
    echo -e "${GREEN}Restore completed!${NC}"
else
    log "ERROR: Restore failed"
    echo -e "${RED}Restore failed!${NC}"
    exit 1
fi
