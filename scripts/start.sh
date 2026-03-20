#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/lib/common.sh"

require_env_file

echo "Starting Core Keeper server..."

run_compose up -d

print_success "Server started!"
echo "View logs with: ./ckserver.sh logs"
