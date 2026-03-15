#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
LOG_FILE="$PROJECT_LOG_DIR/restore_$TIMESTAMP.log"
BACKUP_FILE=""
STAGING_DIR=""
ROLLBACK_DIR=""
RESTORE_COMPLETE=false

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
}

handle_error() {
    local exit_code=$?
    local line_no="$1"
    local failed_command="$2"

    log "ERROR: Restore failed at line $line_no while running: $failed_command"

    if [ "$RESTORE_COMPLETE" != true ] && [ -n "$ROLLBACK_DIR" ] && [ -d "$ROLLBACK_DIR" ] && [ ! -d "$WORLD_DATA_DIR" ]; then
        mv "$ROLLBACK_DIR" "$WORLD_DATA_DIR" || true
        log "Rolled back original world data to: $WORLD_DATA_DIR"
    fi

    print_error "Restore failed!"
    exit "$exit_code"
}

resolve_backup_file() {
    local candidate="$1"

    if [ -f "$candidate" ]; then
        printf '%s' "$candidate"
    elif [ -f "$BACKUPS_DIR/$candidate" ]; then
        printf '%s' "$BACKUPS_DIR/$candidate"
    elif [ -f "$BACKUPS_DIR/core-keeper_backup_$candidate.tar.gz" ]; then
        printf '%s' "$BACKUPS_DIR/core-keeper_backup_$candidate.tar.gz"
    fi
}

select_backup_file() {
    local backups=()
    local choice
    local index

    mapfile -t backups < <(ls -1t "$BACKUPS_DIR"/*.tar.gz 2>/dev/null || true)
    if [ "${#backups[@]}" -eq 0 ]; then
        print_error "No backups found"
        exit 1
    fi

    echo "Available backups:"
    echo ""
    for index in "${!backups[@]}"; do
        printf '%2d) %s\n' "$((index + 1))" "${backups[$index]}"
    done

    echo ""
    read -p "Select backup number to restore: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        print_error "Invalid selection"
        exit 1
    fi

    BACKUP_FILE="${backups[$((choice - 1))]}"
}

verify_backup_file() {
    local checksum_file checksum_expected checksum_actual

    [ -f "$BACKUP_FILE" ] || {
        print_error "Backup file not found: $BACKUP_FILE"
        exit 1
    }

    tar -tzf "$BACKUP_FILE" >/dev/null

    checksum_file="$BACKUP_FILE.sha256"
    if [ -f "$checksum_file" ]; then
        checksum_expected="$(awk '{print $1}' "$checksum_file" | head -1)"
        checksum_actual="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"

        if [ "$checksum_expected" != "$checksum_actual" ]; then
            print_error "Checksum verification failed for: $BACKUP_FILE"
            exit 1
        fi
    fi
}

detect_restored_world_root() {
    if [ -d "$STAGING_DIR/world-data" ]; then
        printf '%s' "$STAGING_DIR/world-data"
        return
    fi

    if [ -d "$STAGING_DIR/worlds" ] || [ -f "$STAGING_DIR/ServerConfig.json" ] || [ -f "$STAGING_DIR/Admins.json" ]; then
        printf '%s' "$STAGING_DIR"
        return
    fi

    return 1
}

trap cleanup EXIT
trap 'handle_error "$LINENO" "$BASH_COMMAND"' ERR

ensure_project_dirs

if [ -n "${1:-}" ]; then
    BACKUP_FILE="$(resolve_backup_file "$1")"
    if [ -z "$BACKUP_FILE" ]; then
        print_error "Backup file not found: $1"
        exit 1
    fi
else
    select_backup_file
fi

verify_backup_file

echo -e "${YELLOW}WARNING: This will replace all current world data!${NC}"
echo "Backup to restore: $BACKUP_FILE"
echo ""
read -p "Are you sure? (yes/no): " -r

if [[ ! "$REPLY" =~ ^yes$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

log "Starting restore from: $BACKUP_FILE"

if is_service_running; then
    log "Stopping server for restore..."
    run_compose down
fi

STAGING_DIR="$(mktemp -d "$DATA_DIR/restore-stage-$TIMESTAMP.XXXXXX")"
tar -xzf "$BACKUP_FILE" -C "$STAGING_DIR" 2>&1 | tee -a "$LOG_FILE"

RESTORED_WORLD_ROOT="$(detect_restored_world_root)"
if [ ! -d "$RESTORED_WORLD_ROOT" ]; then
    print_error "Restore archive did not contain a valid world-data layout."
    exit 1
fi

ROLLBACK_DIR="$DATA_DIR/world-data.pre-restore-$TIMESTAMP"
if [ -d "$WORLD_DATA_DIR" ]; then
    mv "$WORLD_DATA_DIR" "$ROLLBACK_DIR"
    log "Moved current world data to rollback location: $ROLLBACK_DIR"
fi

mv "$RESTORED_WORLD_ROOT" "$WORLD_DATA_DIR"
RESTORE_COMPLETE=true

log "Restore completed successfully"
if [ -d "$ROLLBACK_DIR" ]; then
    log "Rollback copy preserved at: $ROLLBACK_DIR"
fi
print_success "Restore completed!"
