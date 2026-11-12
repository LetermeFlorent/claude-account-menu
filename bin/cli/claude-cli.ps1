. Import-ClmModule claude-cli-args, claude-cli-help, claude-cli-accounts, claude-cli-drive, claude-text
$script:CliRestart = $false

function Write-CliLines {
  param([string[]]$Lines)
  foreach ($l in $Lines) { Write-Host $l }
  return 0
}

function Invoke-CliAction {
  param($Cmd, [object[]]$Argv)
  switch ($Cmd.Name) {
    "help" { return Write-CliLines (Get-CliHelpLines) }
    "version" { return Write-CliLines (Get-CliVersionLines) }
    "list" { return Write-CliLines (Get-CliAccountLines) }
    "backups" { return Write-CliLines (Get-CliBackupLines) }
    "drive-status" { return Write-CliLines (Get-CliDriveLines) }
    "prefs" { return Write-CliLines (Get-CliPrefsLines) }
    "update" { return Invoke-CliUpdate $Argv }
  }
  throw (Get-ClmText "cli.unknownOption" @($Cmd.Name))
}

function Invoke-CliCommand {
  param($Cmd, [object[]]$Argv)
  try { return Invoke-CliAction $Cmd $Argv }
  catch { Write-Host $_.Exception.Message; return 1 }
}
