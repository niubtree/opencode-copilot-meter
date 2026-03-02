# Remote installer for copilot-meter - OpenCode plugin (Windows)
# Usage: irm https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/install.ps1 | iex
$ErrorActionPreference = "Stop"

$RepoBase = "https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main"

$ConfigDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode" }
             else { Join-Path $HOME ".config/opencode" }
$PluginsDir = Join-Path $ConfigDir "plugins"
$ScriptsDir = Join-Path $ConfigDir "scripts/copilot-meter"
$CommandsDir = Join-Path $ConfigDir "commands"

Write-Output "Installing copilot-meter..."
Write-Output ""

foreach ($dir in @($PluginsDir, $ScriptsDir, $CommandsDir)) {
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
}

Write-Output "  plugin  -> $PluginsDir\copilot-meter.js"
Invoke-WebRequest -Uri "$RepoBase/dist/index.js" -OutFile (Join-Path $PluginsDir "copilot-meter.js")

$Scripts = @(
  "copilot-help.ps1",
  "copilot-show-token.ps1",
  "copilot-set-token.ps1",
  "copilot-set-quota-endpoint.ps1",
  "copilot-show-quota.ps1"
)
foreach ($s in $Scripts) {
  Write-Output "  script  -> $ScriptsDir\$s"
  Invoke-WebRequest -Uri "$RepoBase/scripts/$s" -OutFile (Join-Path $ScriptsDir $s)
}

$Commands = @(
  "copilot-help.md",

  "copilot-show-token.md",
  "copilot-show-quota.md",
  "copilot-set-token.md",
  "copilot-set-quota-endpoint.md"
)
foreach ($c in $Commands) {
  Write-Output "  command -> $CommandsDir\$c"
  Invoke-WebRequest -Uri "$RepoBase/commands/$c" -OutFile (Join-Path $CommandsDir $c)
}

Write-Output ""
Write-Output "Done! copilot-meter installed successfully."
Write-Output "Restart OpenCode to activate the slash commands."
Write-Output ""
Write-Output "Usage:"
try { & (Join-Path $ScriptsDir "copilot-help.ps1") } catch {}
