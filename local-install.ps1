# Local installer for copilot-meter - run from cloned repo (Windows)
# Usage:
#   git clone <repo>; cd <repo>
#   pwsh local-install.ps1            # install prebuilt dist/ (no build required)
#   pwsh local-install.ps1 --build    # build from src/ then install (requires Bun)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$Build = $false
if ($args -contains "-h" -or $args -contains "--help") {
  Write-Output "copilot-meter local installer"
  Write-Output ""
  Write-Output "Usage:"
  Write-Output "  pwsh local-install.ps1 [--build]"
  Write-Output ""
  Write-Output "Options:"
  Write-Output "  --build    Build from src/ (requires Bun) before installing"
  exit 0
}
if ($args -contains "--build") {
  $Build = $true
}

if ($Build) {
  if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Error "Error: bun not found. Install Bun or run without --build to use the committed dist/ artifacts."
    exit 1
  }
  Write-Output "Building copilot-meter..."
  Push-Location $ScriptDir
  try { bun run build } finally { Pop-Location }
  Write-Output ""
} elseif (-not (Test-Path (Join-Path $ScriptDir "dist/index.js"))) {
  Write-Error @"
Error: dist/index.js not found.
  - If you're a developer: run 'pwsh local-install.ps1 --build' (requires Bun).
  - If you're an end user: use the remote installer (install.ps1).
"@
  exit 1
}

$ConfigDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode" }
             else { Join-Path $HOME ".config/opencode" }
$PluginsDir = Join-Path $ConfigDir "plugins"
$ScriptsDir = Join-Path $ConfigDir "scripts/copilot-meter"
$CommandsDir = Join-Path $ConfigDir "commands"

Write-Output "Installing copilot-meter (local)..."
Write-Output ""

foreach ($dir in @($PluginsDir, $ScriptsDir, $CommandsDir)) {
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
}

Write-Output "  plugin  -> $PluginsDir\copilot-meter.js"
Copy-Item (Join-Path $ScriptDir "dist/index.js") (Join-Path $PluginsDir "copilot-meter.js") -Force

foreach ($s in (Get-ChildItem (Join-Path $ScriptDir "scripts/copilot-*.ps1"))) {
  Write-Output "  script  -> $ScriptsDir\$($s.Name)"
  Copy-Item $s.FullName (Join-Path $ScriptsDir $s.Name) -Force
}

foreach ($c in (Get-ChildItem (Join-Path $ScriptDir "commands/copilot-*.md"))) {
  Write-Output "  command -> $CommandsDir\$($c.Name)"
  Copy-Item $c.FullName (Join-Path $CommandsDir $c.Name) -Force
}

Write-Output ""
Write-Output "Done! copilot-meter installed successfully."
Write-Output "Restart OpenCode to activate the slash commands."
Write-Output ""
Write-Output "Usage:"
try { & (Join-Path $ScriptsDir "copilot-help.ps1") } catch {}
