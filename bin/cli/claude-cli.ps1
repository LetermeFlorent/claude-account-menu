. Import-ClmModule claude-cli-args, claude-cli-help, claude-cli-accounts, claude-cli-drive, claude-theme, claude-usage-poll, claude-text
$script:CliRestart = $false
$script:CliDisplayNeeds = @{ palette = "cli.palette.needs"; anim = "cli.anim.needs" }
$script:CliDisplayEnv = @{ palette = "STATUSLINE_BG"; anim = "CLM_ANIM" }

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
    "usage-poll" { return Invoke-CliUsagePoll $v }
  }
  throw (Get-ClmText "cli.unknownOption" @($Cmd.Name))
}

function Invoke-CliDisplay {
  param([string]$Name, [string[]]$Values)
  if ($Values.Count -ne 1) { throw (Get-ClmText $script:CliDisplayNeeds[$Name]) }
  if ($Name -eq "palette") { $d = Set-DisplayPalette $Values[0] } else { $d = Set-DisplayAnim $Values[0] }
  Write-Host (Get-ClmText "cli.display.state" @($d.palette, $d.anim))
  if ((Get-DisplayForced)[$Name]) { Write-Host (Get-ClmText "cli.display.forced" @($script:CliDisplayEnv[$Name])) }
  return 0
}

function Invoke-CliUsagePoll {
  param([string[]]$Values)
  if ($Values.Count -ne 1) { throw (Get-ClmText "cli.usagePoll.needs") }
  $n = Set-DisplayUsagePoll $Values[0]
  Write-Host (Get-ClmText "cli.usagePoll.done" @($n))
  return 0
}

function Invoke-CliCommand {
  param($Cmd, [object[]]$Argv)
  try { return Invoke-CliAction $Cmd $Argv }
  catch { Write-Host $_.Exception.Message; return 1 }
}
