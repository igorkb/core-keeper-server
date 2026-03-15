#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
source "$SCRIPT_DIR/lib/common.sh"

BACKUP="${BACKUP:-true}"

echo "Stopping Core Keeper server..."

if [ "$BACKUP" = "true" ]; then
    echo ""
    read -p "Create backup before stopping? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        "$BACKUP_SCRIPT"
    fi
fi

run_compose down

print_success "Server stopped."
