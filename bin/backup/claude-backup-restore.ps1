. Import-ClmModule claude-backup-trust, claude-backup-changes, claude-machine-lock, claude-text
$script:RestoreLockName = "backup"
$script:RestoreLockWaitMs = 3000

function Assert-RestoreAllowed {
  param([string]$Zip, $Accs, [bool]$AllowForeign, [bool]$Yes)
  if (-not (Test-BackupTrusted $Zip)) {
    if (-not $AllowForeign) { throw (Get-ClmText "backup.restore.foreign") }
    Write-Warning (Get-ClmText "backup.restore.foreignWarn")
  }
  $changes = @(Get-RestoreChanges $Zip $Accs)
  if ($changes.Count -gt 0 -and -not $Yes) { throw (Get-ClmText "backup.restore.confirmNeeded" @(($changes -join " ; "))) }
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
  if ($null -eq $lock) { throw (Get-ClmText "backup.restore.busy") }
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
  if ($Accs.Count -eq 0) { throw (Get-ClmText "backup.restore.noAccount") }
  $items = @(Get-AccountItems $Accs | Where-Object { $top -contains $_ })
  $links = @(Get-TarLinkRoots @(& $script:Tar -tvf $Zip))
  foreach ($i in $items) {
    if ($links -contains $i) { throw (Get-ClmText "backup.restore.linkInBackup" @($i)) }
    if (Test-ReparsePath (Join-Path $script:HomeDir $i)) { throw (Get-ClmText "backup.restore.linkOnPc" @($i)) }
  }
  Assert-RestoreAllowed $Zip $Accs $AllowForeign $Yes
  $current = @(Get-Accounts)
  $present = @($current | Where-Object { $d = $_.Dir; @($Accs | Where-Object { $_.Dir -eq $d }).Count -gt 0 })
  $safety = ""
  if ($present.Count -gt 0) { $safety = Save-Accounts "avant-restauration" $present }
  $total = @($entries | Where-Object { $items -contains $_ }).Count
  $script:Sizes = @{}
  $machine = Get-MachineSnapshot @($Accs | ForEach-Object { Join-Path (Get-AccountPath $_) "settings.json" }) (Join-Path (Join-Path $script:HomeDir ".claude") "settings.json")
  $warn = Invoke-Tar (@("-x", "-f", $Zip, "-C", $script:HomeDir) + $items) $total (Get-ClmText "backup.tar.restoring")
  Restore-MachineSnapshot $machine
  $added = @($Accs | Where-Object { $d = $_.Dir; @($current | Where-Object { $_.Dir -eq $d }).Count -eq 0 })
  if ($added.Count -gt 0) { Save-Registry (@($current) + $added) }
  foreach ($acc in Get-Accounts) { Repair-SharedLinks $acc -Force }
  $res = Get-ClmText "backup.restore.done" @((@($Accs | ForEach-Object { $_.Label }) -join ", "))
  if ($safety) { $res += Get-ClmText "backup.restore.safetyKept" @([regex]::Match($safety, '[^\\/]+?\.(zip|tar\.gz)(?= \()').Value) }
  if ($warn.Count -gt 0) { $res += Get-ClmText "backup.restore.skipped" @($warn.Count) }
  return $res
}
