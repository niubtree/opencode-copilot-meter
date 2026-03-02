#!/usr/bin/env bash
# Remote installer for copilot-meter — OpenCode plugin
# Usage: curl -fsSL https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/install.sh | bash
set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
PLUGINS_DIR="$CONFIG_DIR/plugins"
SCRIPTS_DIR="$CONFIG_DIR/scripts/copilot-meter"
COMMANDS_DIR="$CONFIG_DIR/commands"

echo "Installing copilot-meter..."
echo ""

mkdir -p "$PLUGINS_DIR" "$SCRIPTS_DIR" "$COMMANDS_DIR"

echo "  plugin  -> $PLUGINS_DIR/copilot-meter.js"
curl -fsSL "$REPO_BASE/dist/index.js" -o "$PLUGINS_DIR/copilot-meter.js"

SCRIPTS=(
  copilot-help.sh
  copilot-show-token.sh
  copilot-set-token.sh
  copilot-set-quota-endpoint.sh
  copilot-show-quota.sh
)
for s in "${SCRIPTS[@]}"; do
  echo "  script  -> $SCRIPTS_DIR/$s"
  curl -fsSL "$REPO_BASE/scripts/$s" -o "$SCRIPTS_DIR/$s"
done
chmod +x "$SCRIPTS_DIR"/*.sh

COMMANDS=(
  copilot-help.md

  copilot-show-token.md
  copilot-show-quota.md
  copilot-set-token.md
  copilot-set-quota-endpoint.md
)
for c in "${COMMANDS[@]}"; do
  echo "  command -> $COMMANDS_DIR/$c"
  curl -fsSL "$REPO_BASE/commands/$c" -o "$COMMANDS_DIR/$c"
done

echo ""
echo "Done! copilot-meter installed successfully."
echo "Restart OpenCode to activate the slash commands."
echo ""
echo "Usage:"
bash "$SCRIPTS_DIR/copilot-help.sh" || true
