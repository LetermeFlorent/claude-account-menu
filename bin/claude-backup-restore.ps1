. Import-ClmModule claude-backup-trust, claude-backup-changes, claude-machine-lock
$script:RestoreForeignText = "sauvegarde pas creee par clm sur ce PC ou modifiee depuis : la restaurer par clm --restore=<chemin>"
$script:RestoreForeignWarn = "sauvegarde pas creee par clm sur ce PC ou modifiee depuis, restauree a la demande"
$script:RestoreConfirmText = "restauration a confirmer, elle change des reglages qui lancent des commandes : "
$script:RestoreConfirmHow = ". Confirmer dans le menu de clm ou ajouter --yes"
$script:RestoreLockName = "backup"
$script:RestoreLockWaitMs = 3000
$script:RestoreBusyText = "une autre restauration est en cours dans un autre clm : relancer celle-ci quand elle sera finie"

function Assert-RestoreAllowed {
  param([string]$Zip, $Accs, [bool]$AllowForeign, [bool]$Yes)
  if (-not (Test-BackupTrusted $Zip)) {
    if (-not $AllowForeign) { throw $script:RestoreForeignText }
    Write-Warning $script:RestoreForeignWarn
  }
  $changes = @(Get-RestoreChanges $Zip $Accs)
  if ($changes.Count -gt 0 -and -not $Yes) { throw ($script:RestoreConfirmText + ($changes -join " ; ") + $script:RestoreConfirmHow) }
}

function Get-ZipAccounts {
  param([string]$Zip)
  Assert-ArchiveReadable $Zip
  $dirs = @(& $script:Tar -tf $Zip | ForEach-Object { ($_ -split "/")[0] } | Where-Object { Test-AccountDir $_ } | Sort-Object -Unique)
  $reg = @()
  try { $reg = @(((& $script:Tar -xOf $Zip $script:ArchiveRegistryName 2>$null | Out-String) -replace "^[^\[\{]*", "") | ConvertFrom-Json | ForEach-Object { $_ }) } catch { Write-Verbose $_.Exception.Message }
  $out = @()
  foreach ($d in $dirs) {
    $hit = @($reg | Where-Object { $_.Dir -eq $d })
    $label = $d
    if ($hit.Count -gt 0 -and (ConvertTo-AccountLabel $hit[0].Label)) { $label = ConvertTo-AccountLabel $hit[0].Label }
    elseif ($d -eq ".claude") { $label = "compte1" }
    $out += [PSCustomObject]@{ Label = $label; Dir = $d }
  }
  return $out
}

function Restore-Accounts {
  param([string]$Zip, $Accs = $null, [switch]$AllowForeign, [switch]$Yes)
  $lock = Open-MachineLock $script:RestoreLockName $script:RestoreLockWaitMs
  if ($null -eq $lock) { throw $script:RestoreBusyText }
  try { return Invoke-AccountRestore $Zip $Accs $AllowForeign $Yes } finally { Close-MachineLock $lock }
}

function Invoke-AccountRestore {
  param([string]$Zip, $Accs, [bool]$AllowForeign, [bool]$Yes)
  Assert-ArchiveReadable $Zip
  Assert-BackupVersion $Zip
  if ($null -eq $Accs) { $Accs = @(Get-ZipAccounts $Zip) }
  $Accs = @(Select-ValidAccounts $Accs)
  $entries = @(& $script:Tar -tf $Zip | ForEach-Object { ($_ -split "/")[0] })
  $top = @($entries | Sort-Object -Unique)
  $Accs = @($Accs | Where-Object { $top -contains $_.Dir })
  if ($Accs.Count -eq 0) { throw "aucun compte a restaurer dans cette sauvegarde" }
  $items = @(Get-AccountItems $Accs | Where-Object { $top -contains $_ })
  $links = @(Get-TarLinkRoots @(& $script:Tar -tvf $Zip))
  foreach ($i in $items) {
    if ($links -contains $i) { throw ("sauvegarde refusee : " + $i + " y est un lien") }
    if (Test-ReparsePath (Join-Path $script:HomeDir $i)) { throw ("restauration refusee : " + $i + " est un lien sur ce PC") }
  }
  Assert-RestoreAllowed $Zip $Accs $AllowForeign $Yes
  $current = @(Get-Accounts)
  $present = @($current | Where-Object { $d = $_.Dir; @($Accs | Where-Object { $_.Dir -eq $d }).Count -gt 0 })
  $safety = ""
  if ($present.Count -gt 0) { $safety = Save-Accounts "avant-restauration" $present }
  $total = @($entries | Where-Object { $items -contains $_ }).Count
  $script:Sizes = @{}
  $machine = Get-MachineSnapshot @($Accs | ForEach-Object { Join-Path (Get-AccountPath $_) "settings.json" }) (Join-Path (Join-Path $script:HomeDir ".claude") "settings.json")
  $warn = Invoke-Tar (@("-x", "-f", $Zip, "-C", $script:HomeDir) + $items) $total "restauration"
  Restore-MachineSnapshot $machine
  $added = @($Accs | Where-Object { $d = $_.Dir; @($current | Where-Object { $_.Dir -eq $d }).Count -eq 0 })
  if ($added.Count -gt 0) { Save-Registry (@($current) + $added) }
  foreach ($acc in Get-Accounts) { Repair-SharedLinks $acc -Force }
  $res = "restaure : " + (@($Accs | ForEach-Object { $_.Label }) -join ", ")
  if ($safety) { $res += ". Etat precedent garde dans " + [regex]::Match($safety, '[^\\/]+?\.(zip|tar\.gz)(?= \()').Value }
  if ($warn.Count -gt 0) { $res += ", " + $warn.Count + " fichier(s) non restaure(s), en cours d'utilisation ?" }
  return $res
}
