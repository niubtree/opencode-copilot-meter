# Set a new Copilot OAuth token in OpenCode's auth.json
# Usage: copilot-set-token.ps1 <token>
$ErrorActionPreference = "Stop"

$newToken = $args[0]
if (-not $newToken) {
  Write-Output "Usage: copilot-set-token.ps1 <token>"
  Write-Output "Example: copilot-set-token.ps1 gho_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  exit 1
}

$AuthFile = if ($env:XDG_DATA_HOME) { Join-Path $env:XDG_DATA_HOME "opencode/auth.json" }
            else { Join-Path $HOME ".local/share/opencode/auth.json" }

# Function to create new auth entry
function New-CopilotEntry {
  @{
    type = "oauth"
    refresh = $newToken
    access = $newToken
    expires = 0
  }
}

function Write-JsonNoBom {
  param(
    [Parameter(Mandatory = $true)] [string] $Path,
    [Parameter(Mandatory = $true)] $Data
  )
  $json = $Data | ConvertTo-Json -Depth 10
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

# File doesn't exist: create new file with github-copilot
if (-not (Test-Path $AuthFile)) {
  $dir = Split-Path -Parent $AuthFile
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $newData = @{
    "github-copilot" = (New-CopilotEntry)
  }
  Write-JsonNoBom -Path $AuthFile -Data $newData
  Write-Output "Token created successfully (github-copilot)."
  exit 0
}

# File exists: read and update
$data = Get-Content $AuthFile -Raw | ConvertFrom-Json

$key = if ($data.'github-copilot-enterprise') { "github-copilot-enterprise" }
       elseif ($data.'github-copilot') { "github-copilot" }
       else { "github-copilot" }  # Default to personal if neither exists

if ($data.PSObject.Properties.Name -contains $key) {
  $data.$key = New-CopilotEntry
} else {
  $data | Add-Member -NotePropertyName $key -NotePropertyValue (New-CopilotEntry)
}

Write-JsonNoBom -Path $AuthFile -Data $data
Write-Output "Token updated successfully ($key)."
