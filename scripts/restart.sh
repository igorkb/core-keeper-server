#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/lib/common.sh"

echo "Restarting Core Keeper server..."

run_compose restart

print_success "Server restarted!"
