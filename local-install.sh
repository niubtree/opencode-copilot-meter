#!/usr/bin/env bash
# Local installer for copilot-meter — run from cloned repo
# Usage:
#   git clone <repo> && cd <repo>
#   bash local-install.sh          # install prebuilt dist/ (no build required)
#   bash local-install.sh --build  # build from src/ then install (requires Bun)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD=0
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "copilot-meter local installer"
  echo ""
  echo "Usage:"
  echo "  bash local-install.sh [--build]"
  echo ""
  echo "Options:"
  echo "  --build    Build from src/ (requires Bun) before installing"
  exit 0
fi
if [ "${1:-}" = "--build" ]; then
  BUILD=1
fi

if [ "$BUILD" -eq 1 ]; then
  if ! command -v bun >/dev/null 2>&1; then
    echo "Error: bun not found. Install Bun or run without --build to use the committed dist/ artifacts."
    exit 1
  fi
  echo "Building copilot-meter..."
  (cd "$SCRIPT_DIR" && bun run build)
  echo ""
elif [ ! -f "$SCRIPT_DIR/dist/index.js" ]; then
  echo "Error: dist/index.js not found."
  echo "  - If you're a developer: run 'bash local-install.sh --build' (requires Bun)."
  echo "  - If you're an end user: use the remote installer (install.sh)."
  exit 1
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
PLUGINS_DIR="$CONFIG_DIR/plugins"
SCRIPTS_DIR="$CONFIG_DIR/scripts/copilot-meter"
COMMANDS_DIR="$CONFIG_DIR/commands"

echo "Installing copilot-meter (local)..."
echo ""

mkdir -p "$PLUGINS_DIR" "$SCRIPTS_DIR" "$COMMANDS_DIR"

echo "  plugin  -> $PLUGINS_DIR/copilot-meter.js"
cp "$SCRIPT_DIR/dist/index.js" "$PLUGINS_DIR/copilot-meter.js"

for s in "$SCRIPT_DIR"/scripts/copilot-*.sh; do
  name="$(basename "$s")"
  echo "  script  -> $SCRIPTS_DIR/$name"
  cp "$s" "$SCRIPTS_DIR/$name"
done
chmod +x "$SCRIPTS_DIR"/*.sh

for c in "$SCRIPT_DIR"/commands/copilot-*.md; do
  name="$(basename "$c")"
  echo "  command -> $COMMANDS_DIR/$name"
  cp "$c" "$COMMANDS_DIR/$name"
done

echo ""
echo "Done! copilot-meter installed successfully."
echo "Restart OpenCode to activate the slash commands."
echo ""
echo "Usage:"
bash "$SCRIPTS_DIR/copilot-help.sh" || true
