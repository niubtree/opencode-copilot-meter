# Show remaining Copilot premium interactions by querying the configured endpoint
$ErrorActionPreference = "Stop"

$AuthFile = if ($env:XDG_DATA_HOME) { Join-Path $env:XDG_DATA_HOME "opencode/auth.json" }
            else { Join-Path $HOME ".local/share/opencode/auth.json" }
$ConfigDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode" }
             else { Join-Path $HOME ".config/opencode" }
$ConfigFile = Join-Path $ConfigDir "copilot-meter.json"

# Read token
if (-not (Test-Path $AuthFile)) {
  Write-Error "Error: auth file not found: $AuthFile"
  exit 1
}

$authData = Get-Content $AuthFile -Raw | ConvertFrom-Json
$entry = if ($authData.'github-copilot-enterprise') { $authData.'github-copilot-enterprise' }
         elseif ($authData.'github-copilot') { $authData.'github-copilot' }
         else { $null }

if (-not $entry) {
  Write-Error "Error: no github-copilot entry found"
  exit 1
}

$token = $entry.refresh
if (-not $token) {
  Write-Error "Error: no refresh token found"
  exit 1
}

# Read endpoint
if (-not (Test-Path $ConfigFile)) {
  Write-Error "ERROR: config file not found: $ConfigFile`nRun /copilot-set-quota-endpoint to configure it first."
  exit 1
}

$configData = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$endpoint = $configData.quota_endpoint

if (-not $endpoint) {
  Write-Error "ERROR: no quota_endpoint configured`nRun /copilot-set-quota-endpoint to configure it first."
  exit 1
}

$displayEndpoint = $endpoint
try {
  $uri = [Uri]$endpoint
  $hostPort = if ($uri.IsDefaultPort) { $uri.Host } else { "$($uri.Host):$($uri.Port)" }
  $base = if ($uri.UserInfo) { "$($uri.Scheme)://(redacted)@$hostPort$($uri.AbsolutePath)" }
          else { "$($uri.Scheme)://$hostPort$($uri.AbsolutePath)" }
  $displayEndpoint = if ($uri.Query) { "$base?..." } else { $base }
} catch {
  $queryIndex = $endpoint.IndexOf("?")
  if ($queryIndex -ge 0) {
    $displayEndpoint = $endpoint.Substring(0, $queryIndex) + "?..."
  }
}

Write-Output "Querying: $displayEndpoint"
Write-Output ""

try {
  $headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/json"
  }
  $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get
} catch {
  Write-Error "Error: request failed`n$($_.Exception.Message)"
  exit 1
}

$snap = $response.quota_snapshots.premium_interactions
if (-not $snap) {
  Write-Error "Error: premium_interactions not found in response"
  exit 1
}

$remaining   = if ($null -ne $snap.remaining) { $snap.remaining } else { "N/A" }
$quotaRem    = if ($null -ne $snap.quota_remaining) { $snap.quota_remaining } else { "N/A" }
$entitlement = if ($null -ne $snap.entitlement) { $snap.entitlement } else { "N/A" }
$pct         = if ($null -ne $snap.percent_remaining) { $snap.percent_remaining } else { "N/A" }
$unlimited   = if ($null -ne $snap.unlimited) { $snap.unlimited } else { $false }
$resetDate   = if ($null -ne $response.quota_reset_date_utc) { $response.quota_reset_date_utc } else { "N/A" }

Write-Output "Premium interactions remaining: $remaining / $entitlement"
if ($quotaRem -is [double] -or $quotaRem -is [float]) {
  Write-Output ("Quota remaining (fractional):   {0:F2}" -f $quotaRem)
}
if ($pct -is [double] -or $pct -is [float]) {
  Write-Output ("Percent remaining:              {0:F1}%" -f $pct)
}
Write-Output "Unlimited:                      $unlimited"
Write-Output "Quota resets at:                $resetDate"
