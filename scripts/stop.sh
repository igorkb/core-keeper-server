#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$(dirname "$SCRIPT_DIR")/docker-compose.yml"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BACKUP="${BACKUP:-true}"

echo "Stopping Core Keeper server..."

cd "$(dirname "$SCRIPT_DIR")"

if [ "$BACKUP" = "true" ]; then
    echo ""
    read -p "Create backup before stopping? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        "$BACKUP_SCRIPT"
    fi
fi

docker compose -f "$COMPOSE_FILE" down

echo -e "${GREEN}Server stopped.${NC}"
