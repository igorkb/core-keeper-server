#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_BASENAME="core-keeper_backup_$TIMESTAMP.tar.gz"
BACKUP_FILE="$BACKUPS_DIR/$BACKUP_BASENAME"
TMP_BACKUP_FILE="$BACKUP_FILE.tmp"
CHECKSUM_FILE="$BACKUP_FILE.sha256"
LOG_FILE="$PROJECT_LOG_DIR/backup_$TIMESTAMP.log"
BACKUP_RETENTION_COUNT="${BACKUP_RETENTION_COUNT:-3}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    rm -f "$TMP_BACKUP_FILE"
}

handle_error() {
    local exit_code=$?
    local line_no="$1"
    local failed_command="$2"

    log "ERROR: Backup failed at line $line_no while running: $failed_command"
    print_error "Backup failed!"
    exit "$exit_code"
}

prune_old_backups() {
    local backups=()
    local index

    mapfile -t backups < <(ls -1t "$BACKUPS_DIR"/core-keeper_backup_*.tar.gz 2>/dev/null || true)

    if [ "${#backups[@]}" -le "$BACKUP_RETENTION_COUNT" ]; then
        log "Kept ${#backups[@]} backups (within retention limit of $BACKUP_RETENTION_COUNT)"
        return
    fi

    for ((index=BACKUP_RETENTION_COUNT; index<${#backups[@]}; index++)); do
        log "Removing old backup: ${backups[$index]}"
        rm -f "${backups[$index]}" "${backups[$index]}.sha256"
    done

    log "Kept $BACKUP_RETENTION_COUNT newest backups"
}

trap cleanup EXIT
trap 'handle_error "$LINENO" "$BASH_COMMAND"' ERR

ensure_project_dirs

log "Starting backup..."

if [ ! -d "$WORLD_DATA_DIR" ] || [ -z "$(ls -A "$WORLD_DATA_DIR" 2>/dev/null)" ]; then
    log "ERROR: No world data found to backup"
    print_error "Error: No world data found at $WORLD_DATA_DIR"
    exit 1
fi

tar -czf "$TMP_BACKUP_FILE" -C "$DATA_DIR" world-data 2>&1 | tee -a "$LOG_FILE"
tar -tzf "$TMP_BACKUP_FILE" >/dev/null

mv "$TMP_BACKUP_FILE" "$BACKUP_FILE"
sha256sum "$BACKUP_FILE" > "$CHECKSUM_FILE"

SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"
log "Backup created successfully: $BACKUP_FILE ($SIZE)"
log "Checksum written to: $CHECKSUM_FILE"
print_success "Backup created: $BACKUP_FILE ($SIZE)"

prune_old_backups
