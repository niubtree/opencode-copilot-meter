#!/usr/bin/env bash
# Show copilot-meter help: available slash commands and terminal commands
set -euo pipefail

SCRIPTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/scripts/copilot-meter"

cat <<EOF
copilot-meter — Copilot token usage & quota tracker for OpenCode

Slash commands (in OpenCode):
  /copilot-help                      show this help
  /copilot-show-token                show current Copilot OAuth token
  /copilot-set-token                 set Copilot OAuth token (interactive)
  /copilot-show-quota                show remaining premium interactions
  /copilot-set-quota-endpoint        set or clear quota API endpoint (interactive)

Terminal commands:
  $SCRIPTS_DIR/copilot-help.sh
  $SCRIPTS_DIR/copilot-show-token.sh
  $SCRIPTS_DIR/copilot-set-token.sh <token>
  $SCRIPTS_DIR/copilot-show-quota.sh
  $SCRIPTS_DIR/copilot-set-quota-endpoint.sh [url]   (omit url to clear)

Notes:
  - Quota tracking requires the endpoint to be configured first.
  - To clear the quota endpoint, run set-quota-endpoint with no arguments.
EOF
