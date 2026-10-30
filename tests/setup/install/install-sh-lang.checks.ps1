$shCommand = Get-Command sh -ErrorAction SilentlyContinue
if ($shCommand) {
  $shRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
  $shLines = [IO.File]::ReadAllText((Join-Path $shRoot "install.sh")).Replace("`r`n", "`n").Split("`n")
  $shStart = [Array]::FindIndex($shLines, [Predicate[string]]{ param($l) $l -like "list_shipped()*" })
  $shEnd = $shStart
  while ($shLines[$shEnd] -ne "}") { $shEnd++ }
  $shScript = Join-Path $script:Sandbox "list-shipped.sh"
  $null = New-SandboxFile "list-shipped.sh" ((($shLines[$shStart..$shEnd]) -join "`n") + "`nlist_shipped " + "'" + ($bin.Replace("\", "/")) + "'`n")
  $shListed = @(& $shCommand.Source ($shScript.Replace("\", "/")) | ForEach-Object { "" + $_ })
  $shLang = @($shListed | Where-Object { $_ -like "lang/*.json" } | Sort-Object)
  Assert-Equal "lang/en.json lang/fr.json" ($shLang -join " ") "install.sh : list_shipped livre bin/lang/*.json"
  Assert-True ($shListed -contains "claude-menu.ps1") "install.sh : list_shipped livre aussi les scripts de bin"
  Assert-True (-not ($shListed -contains "clm.cmd")) "install.sh : list_shipped ecarte les lanceurs cmd"
  $cfStart = [Array]::FindIndex($shLines, [Predicate[string]]{ param($l) $l -like "check_folders()*" })
  $cfEnd = $cfStart
  while ($shLines[$cfEnd] -ne "}") { $cfEnd++ }
  $cfDst = Join-Path $script:Sandbox "check-folders"
  $null = New-SandboxFile "check-folders/update" "tiers"
  $cfHead = "clm_text() { printf 'BLOCKED %s`n' `"`$3`"; }`ndst='" + $cfDst.Replace("\", "/") + "'`nfiles='claude-menu.ps1`nupdate/claude-update.ps1'`n"
  $null = New-SandboxFile "check-folders.sh" ($cfHead + (($shLines[$cfStart..$cfEnd]) -join "`n") + "`ncheck_folders || exit 3`necho passed`n")
  $cfOut = @(& $shCommand.Source ((Join-Path $script:Sandbox "check-folders.sh").Replace("\", "/")) | ForEach-Object { "" + $_ })
  Assert-Equal ("BLOCKED " + $cfDst.Replace("\", "/") + "/update|3") (($cfOut -join "|") + "|" + $LASTEXITCODE) "install.sh : un fichier au nom d'un dossier livre arrete l'installation avant toute copie"
}
