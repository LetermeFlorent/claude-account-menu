. Import-ClmModule claude-account-move, claude-text, claude-network
$script:CliDateFormat = "dd/MM/yyyy HH:mm"

function Get-CliAccountLines {
  $accs = @(Get-Accounts)
  $lines = for ($i = 0; $i -lt $accs.Count; $i++) {
    $a = $accs[$i]
    ("" + ($i + 1) + "  " + $a.Label.PadRight(12) + " " + $a.Dir.PadRight(18) + " " + (Get-AccountEmail $a)).TrimEnd()
  }
  return ,[string[]]@($lines)
}

function Get-CliBackupLines {
  $files = @(Get-Backups)
  if ($files.Count -eq 0) { return ,[string[]]@(Get-ClmText "accounts.cli.noBackups" @((Get-DownloadsDir))) }
  return ,[string[]]@($files | ForEach-Object { $_.LastWriteTime.ToString($script:CliDateFormat) + "  " + $_.FullName })
}

function Get-CliVersionLines {
  $where = Get-ClmText "accounts.cli.runFrom" @($script:ClmModuleDir)
  if (-not (Test-ClmInstalledHere)) { $where += Get-ClmText "accounts.cli.notInstalledHere" }
  return ,[string[]]@(("clm " + (Format-ClmVersion (Read-ClmVersion))), $where, ("Claude Code " + (Get-ClaudeVersion)))
}

function Invoke-CliUpdate {
  param([object[]]$Argv)
  if (-not (Test-Network)) { throw (Get-ClmText "accounts.network.offline") }
  if (@($Argv) -notcontains "--updated" -and (Update-Clm -Recheck)) { $script:CliRestart = $true; return 0 }
  Write-Host ("clm " + (Format-ClmVersion (Read-ClmVersion)))
  Update-ClaudeForAccounts @(Get-Accounts)
  return 0
}
