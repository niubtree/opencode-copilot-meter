---
description: Set Copilot quota endpoint
---
Ask the user: "Please provide the quota API endpoint URL (leave empty to remove the configuration):"

Once the user responds, detect the operating system and run the appropriate command:
- If they provided a URL:
  - On Windows: `pwsh -NoProfile -Command "& (Join-Path $HOME '.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.ps1') @args" "<URL>"`
  - On macOS/Linux: `bash ~/.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.sh <URL>`
- If they left it empty or said to remove/clear it:
  - On Windows: `pwsh -NoProfile -Command "& (Join-Path $HOME '.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.ps1')"`
  - On macOS/Linux: `bash ~/.config/opencode/scripts/copilot-meter/copilot-set-quota-endpoint.sh`

Then output the result verbatim.
