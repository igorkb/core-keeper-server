#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.deploy.conf"
source "$SCRIPT_DIR/lib/common.sh"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_PATH="${REMOTE_PATH:-}"
KEY_FILE="${KEY_FILE:-}"
SERVICE_NAME="core-keeper"

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
    echo "The script syncs the project, pulls the pinned image, starts the server,"
    echo "and verifies that the container is running on the remote host."
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
    print_success "Created $CONFIG_FILE template. Edit it with your settings."
    exit 0
}

require_value() {
    local option_name="$1"
    local option_value="${2:-}"

    if [ -z "$option_value" ] || [[ "$option_value" == --* ]]; then
        print_error "Error: $option_name requires a value."
        exit 1
    fi
}

validate_key_file() {
    local permissions

    if [ -z "$KEY_FILE" ]; then
        return
    fi

    if [ ! -f "$KEY_FILE" ]; then
        print_error "Error: SSH key file not found: $KEY_FILE"
        exit 1
    fi

    permissions="$(stat -c '%a' "$KEY_FILE" 2>/dev/null || true)"
    if [ -n "$permissions" ] && [ $((10#$permissions % 100)) -ne 0 ]; then
        print_error "Error: SSH key permissions are too open ($permissions). Restrict group/other access before deploying."
        exit 1
    fi
}

build_ssh_opts() {
    SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

    if [ -n "$KEY_FILE" ]; then
        SSH_OPTS+=(-i "$KEY_FILE")
    fi
}

build_rsync_ssh_command() {
    printf '%q ' ssh "${SSH_OPTS[@]}"
}

remote_shell_quote() {
    printf '%q' "$1"
}

run_remote() {
    local remote_command="$1"

    ssh "${SSH_OPTS[@]}" "$REMOTE_USER@$REMOTE_HOST" "$remote_command"
}

remote_preflight() {
    local remote_path_quoted
    local remote_parent_quoted

    remote_path_quoted="$(remote_shell_quote "$REMOTE_PATH")"
    remote_parent_quoted="$(remote_shell_quote "$(dirname "$REMOTE_PATH")")"

    print_warning "Running remote preflight checks..."
    run_remote "set -e; command -v docker >/dev/null; docker compose version >/dev/null; mkdir -p $remote_path_quoted; test -d $remote_path_quoted; test -w $remote_path_quoted || test -w $remote_parent_quoted"
}

sync_project() {
    local ssh_command

    ssh_command="$(build_rsync_ssh_command)"
    print_warning "Syncing project files..."
    rsync -az --delete --progress \
        -e "$ssh_command" \
        --exclude='.git' \
        --exclude='data/server-files' \
        --exclude='data/world-data' \
        --exclude='backups' \
        --exclude='logs' \
        --exclude='*.log' \
        "$PROJECT_ROOT/" \
        "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"
}

deploy_remote_stack() {
    local remote_path_quoted

    remote_path_quoted="$(remote_shell_quote "$REMOTE_PATH")"

    print_warning "Pulling image and starting the remote stack..."
    run_remote "set -e; cd $remote_path_quoted; docker compose --env-file .compose.env pull; docker compose --env-file .compose.env up -d"
}

verify_remote_stack() {
    local remote_path_quoted

    remote_path_quoted="$(remote_shell_quote "$REMOTE_PATH")"

    print_warning "Verifying remote deployment..."
    run_remote "set -e; cd $remote_path_quoted; docker compose --env-file .compose.env ps --status running --services | grep -Fxq $SERVICE_NAME; if [ -s data/server-files/GameID.txt ]; then echo 'GameID:'; cat data/server-files/GameID.txt; else echo 'GameID not generated yet; check logs with ./server.sh logs --docker'; fi"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            require_value "--host" "${2:-}"
            REMOTE_HOST="$2"
            shift 2
            ;;
        --user)
            require_value "--user" "${2:-}"
            REMOTE_USER="$2"
            shift 2
            ;;
        --path)
            require_value "--path" "${2:-}"
            REMOTE_PATH="$2"
            shift 2
            ;;
        --key)
            require_value "--key" "${2:-}"
            KEY_FILE="$2"
            shift 2
            ;;
        --setup) setup_config ;;
        --help) show_help; exit 0 ;;
        *) print_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_PATH" ]; then
    print_error "Error: Remote host and path required"
    echo ""
    show_help
    exit 1
fi

validate_key_file
build_ssh_opts

echo "Deploying to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

remote_preflight
sync_project
deploy_remote_stack
verify_remote_stack

print_success "Deployment complete!"
echo "Remote server updated and started in: $REMOTE_PATH"
