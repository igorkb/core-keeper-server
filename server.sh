#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
BACKUPS_DIR="$SCRIPT_DIR/backups"
DATA_DIR="$SCRIPT_DIR/data"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}     Core Keeper Server Manager${NC}"
    echo -e "${BLUE}========================================${NC}"
}

get_status() {
    if docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null | grep -q "running" 2>/dev/null; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Stopped${NC}"
    fi
}

get_players() {
    if [ -f "$DATA_DIR/world-data/CoreKeeper.log" ]; then
        PLAYERS=$(grep -c "Player.*joined\|Player.*connected" "$DATA_DIR/world-data/CoreKeeper.log" 2>/dev/null || echo "0")
        echo "$PLAYERS/8"
    else
        echo "-"
    fi
}

get_last_backup() {
    if [ -d "$BACKUPS_DIR" ] && [ "$(ls -A "$BACKUPS_DIR" 2>/dev/null)" ]; then
        LATEST=$(ls -t "$BACKUPS_DIR"/*.tar.gz 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            DATE=$(stat -c %y "$LATEST" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$LATEST" 2>/dev/null)
            echo "$DATE"
        else
            echo "None"
        fi
    else
        echo "None"
    fi
}

show_status() {
    print_header
    echo ""
    echo -e "Status:       $(get_status)"
    echo -e "Players:      $(get_players)"
    echo -e "Last Backup:  $(get_last_backup)"
    echo ""
}

show_help() {
    echo "Usage: ./server.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start               Start the server"
    echo "  stop                Stop the server (prompts for backup)"
    echo "  stop --no-backup    Stop without backup"
    echo "  restart             Restart the server"
    echo "  logs                View game logs (last 50 lines)"
    echo "  logs -f             Follow logs live"
    echo "  logs --docker       View container logs"
    echo "  logs --lines N      Custom line count"
    echo "  backup              Create full backup"
    echo "  backup --auto       Backup without prompt"
    echo "  restore             Restore from latest backup"
    echo "  restore <file>      Restore from specific backup"
    echo "  status              Show server status"
    echo "  help                Show this help message"
    echo ""
    echo "Without arguments, runs in interactive mode."
}

show_menu() {
    show_status
    echo "1) Start Server"
    echo "2) Stop Server"
    echo "3) Restart Server"
    echo "4) View Logs"
    echo "5) Follow Logs (live)"
    echo "6) Create Backup"
    echo "7) Restore Backup"
    echo "8) Check Status"
    echo "9) Help"
    echo "10) Exit"
    echo ""
    read -p "Select an option: " choice
    echo ""
    
    case $choice in
        1) "$SCRIPTS_DIR/start.sh" ;;
        2) "$SCRIPTS_DIR/stop.sh" ;;
        3) "$SCRIPTS_DIR/restart.sh" ;;
        4) "$SCRIPTS_DIR/logs.sh" ;;
        5) "$SCRIPTS_DIR/logs.sh" -f ;;
        6) "$SCRIPTS_DIR/backup.sh" ;;
        7) "$SCRIPTS_DIR/restore.sh" ;;
        8) "$SCRIPTS_DIR/status.sh" ;;
        9) show_help ;;
        10) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
}

ensure_env() {
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$SCRIPT_DIR/.env.example" ]; then
            cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
            echo -e "${YELLOW}Created .env file from template. Edit it before starting.${NC}"
        fi
    fi
}

ensure_dirs() {
    mkdir -p "$DATA_DIR/server-files" "$DATA_DIR/world-data" "$BACKUPS_DIR" "$SCRIPT_DIR/logs"
}

main() {
    ensure_dirs
    ensure_env
    
    if [ $# -eq 0 ]; then
        show_menu
        return
    fi
    
    case "$1" in
        start)
            "$SCRIPTS_DIR/start.sh"
            ;;
        stop)
            if [ "${2:-}" = "--no-backup" ]; then
                BACKUP=false "$SCRIPTS_DIR/stop.sh"
            else
                "$SCRIPTS_DIR/stop.sh"
            fi
            ;;
        restart)
            "$SCRIPTS_DIR/restart.sh"
            ;;
        logs)
            shift
            "$SCRIPTS_DIR/logs.sh" "$@"
            ;;
        backup)
            if [ "${2:-}" = "--auto" ]; then
                BACKUP=true "$SCRIPTS_DIR/backup.sh"
            else
                "$SCRIPTS_DIR/backup.sh"
            fi
            ;;
        restore)
            "$SCRIPTS_DIR/restore.sh" "${2:-}"
            ;;
        status)
            "$SCRIPTS_DIR/status.sh"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
