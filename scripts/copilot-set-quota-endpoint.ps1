# Set the Copilot quota endpoint URL used to query remaining premium requests
# Usage: copilot-set-quota-endpoint.ps1 [endpoint]
# If no endpoint provided or empty string, removes the configuration
$ErrorActionPreference = "Stop"

$ConfigDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode" }
             else { Join-Path $HOME ".config/opencode" }
$ConfigFile = Join-Path $ConfigDir "copilot-meter.json"
$endpoint = $args[0]

function Write-JsonNoBom {
  param(
    [Parameter(Mandatory = $true)] [string] $Path,
    [Parameter(Mandatory = $true)] $Data
  )
  $json = $Data | ConvertTo-Json -Depth 10
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function ConvertTo-Hashtable {
  param([Parameter(Mandatory = $true)] $InputObject)
  $table = @{}
  if ($InputObject -is [System.Collections.IDictionary]) {
    foreach ($key in $InputObject.Keys) {
      $table[$key] = $InputObject[$key]
    }
    return $table
  }
  foreach ($prop in $InputObject.PSObject.Properties) {
    $table[$prop.Name] = $prop.Value
  }
  return $table
}

if (-not (Test-Path $ConfigDir)) {
  New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

$data = @{}
if (Test-Path $ConfigFile) {
  $parsed = Get-Content $ConfigFile -Raw | ConvertFrom-Json
  if ($null -ne $parsed) {
    $data = ConvertTo-Hashtable $parsed
  }
}

if ($endpoint -and $endpoint.Trim()) {
  $data["quota_endpoint"] = $endpoint.Trim()
  Write-Output "Quota endpoint saved: $($endpoint.Trim())"
} else {
  $data.Remove("quota_endpoint") | Out-Null
  Write-Output "Quota endpoint removed"
}

Write-JsonNoBom -Path $ConfigFile -Data $data
