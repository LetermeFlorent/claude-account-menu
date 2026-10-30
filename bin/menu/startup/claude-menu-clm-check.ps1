. Import-ClmModule claude-menu-clm-restart
$script:ClmCheckMs = 600000
$script:ClmCheck = $null

function New-ClmCheck {
  param([double]$Now, [bool]$Enabled, $Installed)
  $at = $null
  if ($Enabled) { $at = $Now + $script:ClmCheckMs }
  return @{ Loader = $null; NextAt = $at; Installed = $Installed; Latest = $null }
}

function Test-ClmUpdateReady {
  return $null -ne $script:ClmCheck -and $null -ne $script:ClmCheck.Latest
}

function Step-ClmCheck {
  param($Check, [double]$Now)
  Step-ClmRestart $Now
  if ($null -eq $Check -or $null -eq $Check.NextAt) { return $false }
  $ld = $Check.Loader
  if ($null -eq $ld) {
    if ($Now -ge $Check.NextAt) { $Check.Loader = Start-UsageLoader @(0) (Get-ClmModulePath "claude-self-update") "Get-LatestClm" }
    return $false
  }
  if (-not $ld.Ctl.Done) { return $false }
  $res = Receive-UsageResults $ld
  Close-UsageLoader $ld
  $Check.Loader = $null
  $Check.NextAt = $Now + $script:ClmCheckMs
  $latest = $null
  if ($res.Count -gt 0) { $latest = $res[0][1] }
  if ($null -ne $Check.Latest -or -not (Test-ClmOutdated $Check.Installed $latest)) { return $false }
  $Check.Latest = $latest
  return $true
}

function Stop-ClmCheck {
  if ($null -eq $script:ClmCheck) { return }
  Stop-UsageLoader $script:ClmCheck.Loader 1000
  $script:ClmCheck.Loader = $null
}
