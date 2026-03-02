#!/usr/bin/env bash
# Set a new Copilot OAuth token in OpenCode's auth.json
# Usage: copilot-set-token.sh <token>
set -euo pipefail

AUTH_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json"
new_token="${1:-}"

if [[ -z "$new_token" ]]; then
  echo "Usage: copilot-set-token.sh <token>"
  echo "Example: copilot-set-token.sh gho_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  exit 1
fi

# File doesn't exist: create new file with github-copilot
if [[ ! -f "$AUTH_FILE" ]]; then
  mkdir -p "$(dirname "$AUTH_FILE")"
  cat > "$AUTH_FILE" <<EOF
{
  "github-copilot": {
    "type": "oauth",
    "refresh": "$new_token",
    "access": "$new_token",
    "expires": 0
  }
}
EOF
  echo "Token created successfully (github-copilot)."
  exit 0
fi

# File exists: update existing key or create github-copilot
updated=$(python3 -c "
import json, sys
path = sys.argv[1]
token = sys.argv[2]
with open(path) as f:
    data = json.load(f)
# Determine which key to use
if 'github-copilot-enterprise' in data:
    key = 'github-copilot-enterprise'
elif 'github-copilot' in data:
    key = 'github-copilot'
else:
    key = 'github-copilot'  # Default to personal if neither exists
# Create or update the entry
data[key] = {
    'type': 'oauth',
    'refresh': token,
    'access': token,
    'expires': 0
}
print(json.dumps(data, indent=2))
" "$AUTH_FILE" "$new_token")

echo "$updated" > "$AUTH_FILE"
# Extract the key name for the success message
key=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
if 'github-copilot-enterprise' in data and data['github-copilot-enterprise']['refresh'] == sys.argv[2]:
    print('github-copilot-enterprise')
else:
    print('github-copilot')
" "$AUTH_FILE" "$new_token")
echo "Token updated successfully ($key)."
