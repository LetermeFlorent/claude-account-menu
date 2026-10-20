$script:ClmUpdated = $false
$script:ClmChecked = $false

function Invoke-UiLoader {
  param([string]$Label, $Items, [string]$Source, [string]$Reader)
  $ld = Start-UsageLoader $Items $Source $Reader
  Set-UiProgress $Label -1
  while (-not $ld.Ctl.Done) { Wait-Progress 100 }
  $res = Receive-UsageResults $ld
  Close-UsageLoader $ld
  if ($ld.Ctl.Error) { throw $ld.Ctl.Error }
  if ($res.Count -eq 0) { return $null }
  if ($res[0][2]) { throw $res[0][2] }
  return $res[0][1]
}

function Invoke-ClmStartupUpdate {
  $src = Join-Path $PSScriptRoot "claude-self-update.ps1"
  $res = @{ Updated = $false; Error = "" }
  $null = Invoke-UiWork "Mise a jour de clm" "recherche d'une nouvelle version de clm" {
    $latest = $null
    try { $latest = Invoke-UiLoader "recherche de mise a jour" @(0) $src "Find-ClmUpdate" } catch { return }
    if ($null -eq $latest -or $script:UiQuit) { return }
    $script:WorkPage.Text = "nouvelle version de clm (" + (Format-ClmVersion $latest) + ")"
    try { $null = Invoke-UiLoader ("installation de clm " + (Get-ClmName $latest)) @(, $latest) $src "Install-ClmVersion"; $res.Updated = $true }
    catch { $res.Error = $_.Exception.Message }
  }
  return $res
}

function Invoke-ClaudeStartupUpdate {
  return Invoke-UiWork "Mise a jour de Claude Code" "recherche et installation de la derniere version de Claude Code" { Update-ClaudeForAccounts @(Get-Accounts) }
}

function Add-ClmFailure {
  param($Msg, [string]$Err)
  if (-not $Err) { return $Msg }
  return @(("  mise a jour de clm impossible : " + $Err + "   " + ([string]$Msg[0]).Trim()).TrimEnd(), $script:Ink.Alert)
}

function Invoke-StartupScreens {
  param([bool]$Update, [bool]$SelfUpdate)
  $clm = @{ Updated = $false; Error = "" }
  if ($SelfUpdate -and (Test-ClmInstalledHere)) {
    $script:ClmChecked = $true
    $clm = Invoke-ClmStartupUpdate
    if ($clm.Updated) { $script:ClmUpdated = -not $script:UiQuit; return $false }
  }
  $script:ClmCheck = New-ClmCheck (Get-NowMs) (Test-ClmInstalledHere) (Read-ClmVersion)
  Open-DriveJob
  $script:MenuState = New-MenuState @(Get-Accounts) (Get-NowMs)
  Start-MenuLoader $script:MenuState
  if ($Update -and -not $script:UiQuit) {
    $script:MenuState.Msg = Invoke-ClaudeStartupUpdate
    $script:MenuUpdated = $true
  }
  $script:MenuState.Msg = Add-ClmFailure $script:MenuState.Msg $clm.Error
  return $true
}
