# Show the current Copilot OAuth token stored by OpenCode
$ErrorActionPreference = "Stop"

$AuthFile = if ($env:XDG_DATA_HOME) { Join-Path $env:XDG_DATA_HOME "opencode/auth.json" }
            else { Join-Path $HOME ".local/share/opencode/auth.json" }

if (-not (Test-Path $AuthFile)) {
  Write-Error "Error: auth file not found: $AuthFile"
  exit 1
}

$data = Get-Content $AuthFile -Raw | ConvertFrom-Json
$entry = if ($data.'github-copilot-enterprise') { $data.'github-copilot-enterprise' }
         elseif ($data.'github-copilot') { $data.'github-copilot' }
         else { $null }

if (-not $entry) {
  Write-Error "Error: no github-copilot entry found in auth.json"
  exit 1
}

Write-Output "Copilot token:"
Write-Output $entry.refresh
