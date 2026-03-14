#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$(dirname "$SCRIPT_DIR")/docker-compose.yml"
ENV_FILE="$(dirname "$SCRIPT_DIR")/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found. Copy .env.example to .env and configure it.${NC}"
    exit 1
fi

echo "Starting Core Keeper server..."

cd "$(dirname "$SCRIPT_DIR")"
docker compose -f "$COMPOSE_FILE" up -d

echo -e "${GREEN}Server started!${NC}"
echo "View logs with: ./server.sh logs"
