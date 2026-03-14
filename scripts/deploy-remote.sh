#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.deploy.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_PATH="${REMOTE_PATH:-}"
KEY_FILE="${KEY_FILE:-}"

show_help() {
    echo "Usage: ./deploy-remote.sh [options]"
    echo ""
    echo "Options:"
    echo "  --host <host>       Remote server hostname/IP"
    echo "  --user <user>       SSH user (default: root)"
    echo "  --path <path>       Remote deployment path"
    echo "  --key <file>        SSH private key file"
    echo "  --setup             Create .deploy.conf template"
    echo "  --help              Show this help"
    echo ""
    echo "Or configure defaults in .deploy.conf"
}

setup_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Remote Deployment Configuration
# Copy this file and fill in your values

REMOTE_HOST="your-server-ip"
REMOTE_USER="root"
REMOTE_PATH="/opt/core-keeper-server"
KEY_FILE="~/.ssh/id_rsa"
EOF
    echo -e "${GREEN}Created $CONFIG_FILE template. Edit it with your settings.${NC}"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host) REMOTE_HOST="$2"; shift 2 ;;
        --user) REMOTE_USER="$2"; shift 2 ;;
        --path) REMOTE_PATH="$2"; shift 2 ;;
        --key) KEY_FILE="$2"; shift 2 ;;
        --setup) setup_config ;;
        --help) show_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_PATH" ]; then
    echo -e "${RED}Error: Remote host and path required${NC}"
    echo ""
    show_help
    exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
[ -n "$KEY_FILE" ] && SSH_OPTS="$SSH_OPTS -i $KEY_FILE"

echo "Deploying to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

echo "Creating remote directory..."
ssh $SSH_OPTS "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_PATH"

echo "Syncing files..."
rsync -avz --progress \
    -e "ssh $SSH_OPTS" \
    --exclude='data/server-files' \
    --exclude='backups' \
    --exclude='logs' \
    --exclude='*.log' \
    "$(dirname "$SCRIPT_DIR")/" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"

echo "Building Docker image on remote..."
ssh $SSH_OPTS "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_PATH && docker compose build"

echo -e "${GREEN}Deployment complete!${NC}"
echo "Connect to server and run: cd $REMOTE_PATH && ./server.sh start"
