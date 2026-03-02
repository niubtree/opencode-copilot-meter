#!/usr/bin/env bash
# Show the current Copilot OAuth token stored by OpenCode
set -euo pipefail

AUTH_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json"

if [[ ! -f "$AUTH_FILE" ]]; then
  echo "Error: auth file not found: $AUTH_FILE" >&2
  exit 1
fi

token=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
entry = data.get('github-copilot-enterprise') or data.get('github-copilot')
if not entry:
    print('Error: no github-copilot entry found in auth.json', file=sys.stderr)
    sys.exit(1)
print(entry.get('refresh', ''))
" < "$AUTH_FILE")

echo "Copilot token:"
echo "$token"
