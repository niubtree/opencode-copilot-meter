#!/usr/bin/env bash
# Show remaining Copilot premium interactions by querying the configured endpoint
set -euo pipefail

AUTH_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
CONFIG_FILE="$CONFIG_DIR/copilot-meter.json"

# Read token
if [[ ! -f "$AUTH_FILE" ]]; then
  echo "Error: auth file not found: $AUTH_FILE" >&2
  exit 1
fi

token=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
entry = data.get('github-copilot-enterprise') or data.get('github-copilot')
if not entry:
    print('Error: no github-copilot entry found', file=sys.stderr)
    sys.exit(1)
print(entry.get('refresh', ''))
" "$AUTH_FILE") || { echo "Error: failed to read token from $AUTH_FILE" >&2; exit 1; }

if [[ -z "$token" ]]; then
  echo "Error: no refresh token found in $AUTH_FILE" >&2
  exit 1
fi

# Read endpoint
endpoint=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    ep = data.get('quota_endpoint', '')
    if ep:
        print(ep)
    else:
        print('ERROR: no quota_endpoint configured', file=sys.stderr)
        print('Run /copilot-set-quota-endpoint to configure it first.', file=sys.stderr)
        sys.exit(1)
except FileNotFoundError:
    print('ERROR: config file not found: ' + sys.argv[1], file=sys.stderr)
    print('Run /copilot-set-quota-endpoint to configure it first.', file=sys.stderr)
    sys.exit(1)
" "$CONFIG_FILE") || exit 1

display_endpoint="$endpoint"
if [[ "$display_endpoint" == *"://"* ]]; then
  scheme="${display_endpoint%%://*}"
  rest="${display_endpoint#*://}"
  if [[ "$rest" == *"@"* ]]; then
    host_and_path="${rest#*@}"
    display_endpoint="${scheme}://(redacted)@${host_and_path}"
  fi
fi
if [[ "$display_endpoint" == *"?"* ]]; then
  display_endpoint="${display_endpoint%%\?*}?…"
fi

echo "Querying: $display_endpoint"
echo ""

response=$(curl -sf \
  -H "Authorization: Bearer $token" \
  -H "Accept: application/json" \
  "$endpoint") || { echo "Error: request failed" >&2; exit 1; }

# Parse response via stdin to avoid ARG_MAX limits on large JSON
echo "$response" | python3 -c "
import json, sys
data = json.load(sys.stdin)
snap = data.get('quota_snapshots', {}).get('premium_interactions', {})
if not snap:
    print('Error: premium_interactions not found in response')
    sys.exit(1)

remaining   = snap.get('remaining', 'N/A')
quota_rem   = snap.get('quota_remaining', 'N/A')
entitlement = snap.get('entitlement', 'N/A')
pct         = snap.get('percent_remaining', 'N/A')
unlimited   = snap.get('unlimited', False)
reset_date  = data.get('quota_reset_date_utc', 'N/A')

print(f'Premium interactions remaining: {remaining} / {entitlement}')
if isinstance(quota_rem, float):
    print(f'Quota remaining (fractional):   {quota_rem:.2f}')
if isinstance(pct, float):
    print(f'Percent remaining:              {pct:.1f}%')
print(f'Unlimited:                      {unlimited}')
print(f'Quota resets at:                {reset_date}')
"
