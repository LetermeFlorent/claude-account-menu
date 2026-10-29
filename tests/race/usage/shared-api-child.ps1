param([string]$Bin, [string]$Lab, [string]$Gate, [string]$Calls, [string]$Id, [string]$Mode)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-usage

function Stop-RaceNetwork { throw "reseau interdit pendant les tests" }
Set-Alias -Name Invoke-RestMethod -Value Stop-RaceNetwork
Set-Alias -Name Invoke-WebRequest -Value Stop-RaceNetwork

function Read-AccountCredential {
  param($Acc)
  return [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "faux"; expiresAt = 0; subscriptionType = "pro" } }
}

function Update-AccountToken { throw "jeton interdit pendant les tests" }

function Get-UsageToken {
  param($Acc, $Cred, [switch]$NoRefresh)
  return @{ Token = "faux" }
}

function Invoke-UsageApi {
  param([string]$Token)
  [IO.File]::WriteAllText((Join-Path $Calls ("call-" + $Id + "-" + [guid]::NewGuid().ToString("N"))), $Id)
  Start-Sleep -Milliseconds 1000
  if ($Mode -eq "refuse") {
    $e = New-Object Exception "trop de requetes"
    Add-Member -InputObject $e -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = 429; Headers = @{ "Retry-After" = "300" } })
    throw $e
  }
  return [PSCustomObject]@{ five_hour = [PSCustomObject]@{ utilization = 42; resets_at = "2030-01-01T00:00:00Z" }; seven_day = [PSCustomObject]@{ utilization = 7; resets_at = "2030-01-03T00:00:00Z" } }
}

Wait-RaceGate $Gate $Id
$u = Get-AccountUsage ([PSCustomObject]@{ Label = "course"; Dir = ".claude-course" })
"result " + $Id + " " + $u.Pct5 + " " + $u.LimitedUntil + " " + $u.Error
