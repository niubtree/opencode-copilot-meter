#!/usr/bin/env bash
# Set the Copilot quota endpoint URL used to query remaining premium requests
# Usage: copilot-set-quota-endpoint.sh [endpoint]
# If no endpoint provided or empty string, removes the configuration
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
CONFIG_FILE="$CONFIG_DIR/copilot-meter.json"
endpoint="${1:-}"

mkdir -p "$CONFIG_DIR"

python3 -c "
import json, sys
path, endpoint = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}

if endpoint.strip():
    data['quota_endpoint'] = endpoint.strip()
    print('Quota endpoint saved:', endpoint.strip())
else:
    data.pop('quota_endpoint', None)
    print('Quota endpoint removed')
    
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" "$CONFIG_FILE" "$endpoint"
