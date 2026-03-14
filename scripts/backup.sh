#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
BACKUPS_DIR="$(dirname "$SCRIPT_DIR")/backups"
DATA_DIR="$(dirname "$SCRIPT_DIR")/data"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="$BACKUPS_DIR/core-keeper_backup_$TIMESTAMP.tar.gz"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$LOG_DIR" "$BACKUPS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/backup_$TIMESTAMP.log"
}

log "Starting backup..."

if [ ! -d "$DATA_DIR/world-data" ] || [ -z "$(ls -A "$DATA_DIR/world-data" 2>/dev/null)" ]; then
    log "ERROR: No world data found to backup"
    echo -e "${RED}Error: No world data found at $DATA_DIR/world-data${NC}"
    exit 1
fi

tar -czf "$BACKUP_FILE" -C "$DATA_DIR" world-data 2>&1 | tee -a "$LOG_DIR/backup_$TIMESTAMP.log"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup created successfully: $BACKUP_FILE ($SIZE)"
    echo -e "${GREEN}Backup created: $BACKUP_FILE ($SIZE)${NC}"
    
    find "$BACKUPS_DIR" -name "core-keeper_backup_*.tar.gz" -type f | \
        tail -n +4 | xargs -r rm
    
    OLD_COUNT=$(find "$BACKUPS_DIR" -name "core-keeper_backup_*.tar.gz" -type f | wc -l)
    log "Kept $OLD_COUNT backups (removed older ones)"
else
    log "ERROR: Backup failed"
    echo -e "${RED}Backup failed!${NC}"
    exit 1
fi
