if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-self-guard, claude-text
$script:ClmGroups = @{
  drive = @("claude-drive-sync", "claude-drive-lock", "claude-sync-passphrase", "claude-drive-login", "claude-drive-watch-launch", "claude-drive-creds")
  sync = @("claude-sync", "claude-sync-catalog", "claude-sync-choice", "claude-sync-asks")
  mcp = @("claude-mcp-projects", "claude-mcp-globals", "claude-mcp-keys")
  web = @("claude-web-server", "claude-web-state", "claude-web-lists", "claude-web-actions")
}
$script:ClmGroupProbes = @{ drive = "Invoke-DriveSync"; sync = "Sync-Accounts"; mcp = "Get-GlobalDefs"; web = "Start-WebServer" }
if ($null -eq $script:ClmGroupsLoaded) { $script:ClmGroupsLoaded = New-Object 'System.Collections.Generic.HashSet[string]' }
if ($null -eq $script:ClmGroupStamp) { $script:ClmGroupStamp = $script:ClmEntryStamp }
if ($null -eq $script:ClmGroupStamp) { $script:ClmGroupStamp = Read-ClmStamp }

function Test-ClmGroupLoaded {
  param([string]$Name)
  if ($script:ClmGroupsLoaded.Contains($Name)) { return $true }
  return $null -eq $script:ClmOnce -and (Test-Path ("Function:\" + $script:ClmGroupProbes[$Name]))
}

function Test-ClmGroupStamp {
  param([string]$Stamp)
  return $Stamp -cne $script:ClmInstallingStamp -and $Stamp -ceq $script:ClmGroupStamp
}

function Get-ClmFunctionMap {
  $map = @{}
  foreach ($f in Get-ChildItem Function:) { $map[$f.Name] = $f.ScriptBlock }
  return $map
}

function Import-ClmGroup {
  param([string[]]$ClmGroupNames)
  $ClmGroupWanted = @($ClmGroupNames | Where-Object { -not (Test-ClmGroupLoaded $_) })
  if ($ClmGroupWanted.Count -eq 0) { return $true }
  $ClmGroupStampNow = Read-ClmStamp
  if (-not (Test-ClmGroupStamp $ClmGroupStampNow)) { $script:ClmRestartDue = $true; return $false }
  $ClmGroupBefore = Get-ClmFunctionMap
  foreach ($ClmGroupName in $ClmGroupWanted) { . Import-ClmModule $script:ClmGroups[$ClmGroupName] }
  $ClmGroupAfter = Get-ClmFunctionMap
  foreach ($ClmGroupFn in @($ClmGroupAfter.Keys)) {
    if (-not [object]::ReferenceEquals($ClmGroupBefore[$ClmGroupFn], $ClmGroupAfter[$ClmGroupFn])) { Set-Item -Path ("Function:script:" + $ClmGroupFn) -Value $ClmGroupAfter[$ClmGroupFn] }
  }
  if ((Read-ClmStamp) -cne $ClmGroupStampNow) { $script:ClmRestartDue = $true; return $false }
  foreach ($ClmGroupName in $ClmGroupWanted) { [void]$script:ClmGroupsLoaded.Add($ClmGroupName) }
  return $true
}

function Assert-ClmGroup {
  param([string[]]$Names)
  if (-not (Import-ClmGroup $Names)) { throw (Get-ClmText "menu.groups.replaced") }
}

function Import-ClmGroupOrReload {
  param([string[]]$Names, [string]$Script, [object[]]$Argv)
  if (Import-ClmGroup $Names) { return }
  if (-not $script:ClmReloaded) {
    if (Test-Path Function:\Stop-BootBar) { Stop-BootBar }
    Invoke-ClmReload $Script $Argv
    return
  }
  $script:ClmGroupStamp = Wait-ClmInstall
  if (-not (Import-ClmGroup $Names)) { throw (Get-ClmText "menu.groups.replaced") }
}
