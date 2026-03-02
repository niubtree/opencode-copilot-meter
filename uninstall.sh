#!/usr/bin/env bash
# Uninstaller for copilot-meter — removes all deployed files
# Usage: curl -fsSL https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/uninstall.sh | bash
#    or: bash uninstall.sh
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

echo "Uninstalling copilot-meter..."
echo ""

# Plugin
if [ -f "$CONFIG_DIR/plugins/copilot-meter.js" ]; then
  rm "$CONFIG_DIR/plugins/copilot-meter.js"
  echo "  removed $CONFIG_DIR/plugins/copilot-meter.js"
fi

# Scripts directory
if [ -d "$CONFIG_DIR/scripts/copilot-meter" ]; then
  rm -rf "$CONFIG_DIR/scripts/copilot-meter"
  echo "  removed $CONFIG_DIR/scripts/copilot-meter/"
fi

# Slash commands
removed=0
for f in "$CONFIG_DIR/commands"/copilot-*.md; do
  [ -f "$f" ] || continue
  rm "$f"
  echo "  removed $f"
  removed=$((removed + 1))
done
[ "$removed" -eq 0 ] && echo "  no slash commands found"

echo ""
echo "Done! copilot-meter uninstalled."
echo "Config file preserved: $CONFIG_DIR/copilot-meter.json (if it exists)"
echo "Restart OpenCode to complete removal."
