. Import-ClmModule claude-account-move
$script:CliDateFormat = "dd/MM/yyyy HH:mm"

function Find-CliAccount {
  param($Accs, [string]$Ref)
  $list = @($Accs)
  if ($Ref -match "^[1-9]$" -and [int]$Ref -le $list.Count) { return $list[[int]$Ref - 1] }
  $hit = @($list | Where-Object { $_.Label -eq $Ref -or $_.Dir -eq $Ref })
  if ($hit.Count -eq 0) { throw ("compte inconnu : " + $Ref + ", voir clm --list") }
  return $hit[0]
}

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
  if ($files.Count -eq 0) { return ,[string[]]@("aucune archive dans " + (Get-DownloadsDir)) }
  return ,[string[]]@($files | ForEach-Object { $_.LastWriteTime.ToString($script:CliDateFormat) + "  " + $_.FullName })
}

function Get-CliVersionLines {
  $where = "lance depuis " + $PSScriptRoot
  if (-not (Test-ClmInstalledHere)) { $where += ", hors de .local/bin : pas de mise a jour automatique" }
  return ,[string[]]@(("clm " + (Format-ClmVersion (Read-ClmVersion))), $where, ("Claude Code " + (Get-ClaudeVersion)))
}

function Invoke-CliAdd {
  param([string[]]$Values)
  if ($Values.Count -gt 1) { throw "--add attend au plus un nom, entre guillemets s'il a des espaces" }
  $name = ""
  if ($Values.Count -eq 1) { $name = $Values[0].Trim() }
  if ($name) { Assert-AccountName $name "" @(Get-Accounts) }
  Write-Host "connexion dans le navigateur : une personne doit choisir le compte Claude"
  Write-Host (Connect-NewAccount $name)
  return 0
}

function Invoke-CliRename {
  param([string[]]$Values)
  if ($Values.Count -ne 2) { throw "--rename attend un compte puis un nom" }
  Write-Host (Rename-Account (Find-CliAccount (Get-Accounts) $Values[0]) $Values[1])
  return 0
}

function Invoke-CliMove {
  param([string[]]$Values)
  if ($Values.Count -ne 2 -or $Values[1] -notmatch "^[0-9]+$") { throw "--move attend un compte puis un rang, 1 pour le haut du menu" }
  Write-Host (Move-Account (Find-CliAccount (Get-Accounts) $Values[0]) ([int]$Values[1]))
  return 0
}

function Get-CliRemovePlan {
  param($Acc, [bool]$Erase)
  $what = "retirer " + $Acc.Label + " (" + $Acc.Dir + ") du menu"
  if ($Erase) { return $what + " et effacer son dossier, apres une archive dans Telechargements" }
  return $what + ", son dossier reste en place"
}

function Invoke-CliRemove {
  param($Cmd)
  if (@($Cmd.Values).Count -ne 1) { throw "--remove attend un compte" }
  $acc = Find-CliAccount (Get-Accounts) $Cmd.Values[0]
  if ($Cmd.Erase -and -not (Test-ErasableDir $acc.Dir)) { throw ("le dossier " + $acc.Dir + " n'est jamais efface") }
  if (-not $Cmd.Yes) { throw ((Get-CliRemovePlan $acc $Cmd.Erase) + " : ajouter --yes pour confirmer") }
  Write-Host (Remove-Account $acc $Cmd.Erase)
  return 0
}

function Invoke-CliUpdate {
  param([object[]]$Argv)
  if (-not (Test-Network)) { throw $script:OfflineText }
  if (@($Argv) -notcontains "--updated" -and (Update-Clm -Recheck)) { $script:CliRestart = $true; return 0 }
  Write-Host ("clm " + (Format-ClmVersion (Read-ClmVersion)))
  Update-ClaudeForAccounts @(Get-Accounts)
  return 0
}
