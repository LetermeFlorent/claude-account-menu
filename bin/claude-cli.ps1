if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-cli-help.ps1")) { . (Join-Path $PSScriptRoot "claude-cli-help.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-cli-accounts.ps1")) { . (Join-Path $PSScriptRoot "claude-cli-accounts.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-cli-drive.ps1")) { . (Join-Path $PSScriptRoot "claude-cli-drive.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-theme.ps1")) { . (Join-Path $PSScriptRoot "claude-theme.ps1") }
$script:CliRestart = $false
$script:CliCommands = @("--help", "-h", "--version", "--list", "--add", "--rename", "--move", "--remove", "--backups", "--update", "--drive-status", "--prefs", "--prefs-on", "--prefs-off", "--prefs-erase", "--palette", "--anim")
$script:CliDisplayNeeds = @{ palette = "--palette attend auto, dark ou light"; anim = "--anim attend auto, on ou off" }
$script:CliDisplayEnv = @{ palette = "STATUSLINE_BG"; anim = "CLM_ANIM" }

function Get-CliCommand {
  param([object[]]$ArgList)
  $list = [string[]]@($ArgList | ForEach-Object { [string]$_ })
  if (@($list | Where-Object { $_ -match "^-[1-9]$" }).Count -gt 0) { return $null }
  for ($i = 0; $i -lt $list.Count; $i++) {
    if ($script:CliCommands -notcontains $list[$i]) { continue }
    $rest = @($list | Select-Object -Skip ($i + 1))
    $name = $list[$i].TrimStart("-")
    if ($name -eq "h") { $name = "help" }
    return @{ Name = $name; Values = [string[]]@($rest | Where-Object { -not $_.StartsWith("--") }); Yes = $list -contains "--yes"; Erase = $list -contains "--erase" }
  }
  return $null
}

function Write-CliLines {
  param([string[]]$Lines)
  foreach ($l in $Lines) { Write-Host $l }
  return 0
}

function Invoke-CliAction {
  param($Cmd, [object[]]$Argv)
  $v = [string[]]@($Cmd.Values)
  switch ($Cmd.Name) {
    "help" { return Write-CliLines (Get-CliHelpLines) }
    "version" { return Write-CliLines (Get-CliVersionLines) }
    "list" { return Write-CliLines (Get-CliAccountLines) }
    "backups" { return Write-CliLines (Get-CliBackupLines) }
    "drive-status" { return Write-CliLines (Get-CliDriveLines) }
    "prefs" { return Write-CliLines (Get-CliPrefsLines) }
    "add" { return Invoke-CliAdd $v }
    "rename" { return Invoke-CliRename $v }
    "move" { return Invoke-CliMove $v }
    "remove" { return Invoke-CliRemove $Cmd }
    "update" { return Invoke-CliUpdate $Argv }
    "prefs-on" { return Invoke-CliPrefsChange "on" $v $Cmd.Yes }
    "prefs-off" { return Invoke-CliPrefsChange "off" $v $Cmd.Yes }
    "prefs-erase" { return Invoke-CliPrefsChange "erase" $v $Cmd.Yes }
    "palette" { return Invoke-CliDisplay "palette" $v }
    "anim" { return Invoke-CliDisplay "anim" $v }
  }
  throw ("option inconnue : --" + $Cmd.Name)
}

function Invoke-CliDisplay {
  param([string]$Name, [string[]]$Values)
  if ($Values.Count -ne 1) { throw $script:CliDisplayNeeds[$Name] }
  if ($Name -eq "palette") { $d = Set-DisplayPalette $Values[0] } else { $d = Set-DisplayAnim $Values[0] }
  Write-Host ("affichage de ce PC : couleurs " + $d.palette + ", animations " + $d.anim)
  if ((Get-DisplayForced)[$Name]) { Write-Host ($script:CliDisplayEnv[$Name] + " est definie et passe avant ce reglage") }
  return 0
}

function Invoke-CliCommand {
  param($Cmd, [object[]]$Argv)
  try { return Invoke-CliAction $Cmd $Argv }
  catch { Write-Host $_.Exception.Message; return 1 }
}
