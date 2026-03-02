# copilot-meter help - available slash commands and terminal commands
$ErrorActionPreference = "Stop"

$ScriptsDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode\scripts\copilot-meter" }
              else { Join-Path $HOME ".config\opencode\scripts\copilot-meter" }

Write-Output @"
copilot-meter - Copilot token usage & quota tracker for OpenCode

Slash commands (in OpenCode):
  /copilot-help                      show this help
  /copilot-show-token                show current Copilot OAuth token
  /copilot-set-token                 set Copilot OAuth token (interactive)
  /copilot-show-quota                show remaining premium interactions
  /copilot-set-quota-endpoint        set or clear quota API endpoint (interactive)

Terminal commands:
  $ScriptsDir\copilot-help.ps1
  $ScriptsDir\copilot-show-token.ps1
  $ScriptsDir\copilot-set-token.ps1 <token>
  $ScriptsDir\copilot-show-quota.ps1
  $ScriptsDir\copilot-set-quota-endpoint.ps1 [url]   (omit url to clear)

Notes:
  - Quota tracking requires the endpoint to be configured first.
  - To clear the quota endpoint, run set-quota-endpoint with no arguments.
"@
