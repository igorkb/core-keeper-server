#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$(dirname "$SCRIPT_DIR")/docker-compose.yml"

GREEN='\033[0;32m'
NC='\033[0m'

echo "Restarting Core Keeper server..."

cd "$(dirname "$SCRIPT_DIR")"
docker compose -f "$COMPOSE_FILE" restart

echo -e "${GREEN}Server restarted!${NC}"
