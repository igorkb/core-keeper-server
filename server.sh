#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

source "$SCRIPT_DIR/scripts/lib/common.sh"

get_status() {
    if is_service_running; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Stopped${NC}"
    fi
}

get_players() {
    get_connected_players
}

get_last_backup() {
    local latest date

    latest="$(latest_backup_file)"
    if [ -n "$latest" ]; then
        date="$(file_date "$latest")"
        if [ -n "$date" ]; then
            echo "$date"
        else
            echo "Unknown"
        fi
    else
        echo "None"
    fi
}

show_status() {
    print_header "Core Keeper Server Manager"
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
    echo "  backup --auto       Create full backup (automation-friendly alias)"
    echo "  restore             Choose and restore a backup interactively"
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
    if [ ! -f "$ENV_FILE" ] && [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
        print_warning "Created .env file from template. Review it before starting the server."
    fi
}

main() {
    ensure_project_dirs
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
            "$SCRIPTS_DIR/backup.sh"
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
