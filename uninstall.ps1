# Uninstaller for copilot-meter - removes all deployed files (Windows)
# Usage: irm https://raw.githubusercontent.com/niubtree/opencode-copilot-meter/main/uninstall.ps1 | iex
#    or: pwsh uninstall.ps1
$ErrorActionPreference = "Stop"

$ConfigDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode" }
             else { Join-Path $HOME ".config/opencode" }

Write-Output "Uninstalling copilot-meter..."
Write-Output ""

# Plugin
$pluginPath = Join-Path $ConfigDir "plugins/copilot-meter.js"
if (Test-Path $pluginPath) {
  Remove-Item $pluginPath -Force
  Write-Output "  removed $pluginPath"
}

# Scripts directory
$scriptsPath = Join-Path $ConfigDir "scripts/copilot-meter"
if (Test-Path $scriptsPath) {
  Remove-Item $scriptsPath -Recurse -Force
  Write-Output "  removed $scriptsPath"
}

# Slash commands
$removed = 0
foreach ($f in (Get-ChildItem (Join-Path $ConfigDir "commands/copilot-*.md") -ErrorAction SilentlyContinue)) {
  Remove-Item $f.FullName -Force
  Write-Output "  removed $($f.FullName)"
  $removed++
}
if ($removed -eq 0) {
  Write-Output "  no slash commands found"
}

Write-Output ""
Write-Output "Done! copilot-meter uninstalled."
Write-Output "Config file preserved: $(Join-Path $ConfigDir 'copilot-meter.json') (if it exists)"
Write-Output "Restart OpenCode to complete removal."
