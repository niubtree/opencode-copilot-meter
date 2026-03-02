---
description: Set Copilot OAuth token
---
Ask the user: "Please provide the Copilot OAuth token to set (format: gho_...):"

Once the user provides the token, detect the operating system and run the appropriate command using the bash tool:
- On Windows: `pwsh -NoProfile -Command "& (Join-Path $HOME '.config/opencode/scripts/copilot-meter/copilot-set-token.ps1') @args" "<TOKEN>"`
- On macOS/Linux: `bash ~/.config/opencode/scripts/copilot-meter/copilot-set-token.sh <TOKEN>`

Replace `<TOKEN>` with the value provided by the user. Then output the result verbatim.
