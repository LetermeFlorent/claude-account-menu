. Import-ClmModule claude-text
function Get-RestoreWarn {
  param($Changes = @())
  $rows = New-Object System.Collections.Generic.List[object]
  $rows.Add((New-TextRow ("  " + (Get-ClmText "backup.menu.restore.replace")) $script:Ink.Dim))
  $rows.Add((New-TextRow ("  " + (Get-ClmText "backup.menu.restore.safety")) $script:Ink.Dim))
  $rows.Add((New-TextRow ("  " + (Get-ClmText "backup.menu.restore.closeSessions")) $script:Ink.Dim))
  $rows.Add((New-TextRow ("  " + (Get-ClmText "backup.menu.restore.relogin")) $script:Ink.Dim))
  if (@($Changes).Count -eq 0) { return ,$rows }
  $rows.Add((New-TextRow ("  " + (Get-ClmText "backup.menu.restore.changes")) $script:Ink.Alert))
  foreach ($c in @($Changes)) { $rows.Add((New-TextRow ("    " + $c) $script:Ink.Alert)) }
  return ,$rows
}

function Show-RestoreMenu {
  $list = @(Get-Backups | Select-Object -First 9)
  $title = Get-ClmText "backup.menu.restore.title"
  $dir = Get-DownloadsDir
  if ($list.Count -eq 0) {
    $null = Read-PageKey { Get-PageRows $title @(, (New-TextRow ("  " + (Get-ClmText "backup.menu.restore.noneRow")) $script:Ink.Dim)) @() $dir }
    return Get-ClmText "backup.menu.restore.none"
  }
  $items = @(foreach ($f in $list) { $f.LastWriteTime.ToString("dd/MM/yyyy HH:mm") + "  " + (Get-ClmText "backup.size" @([math]::Round($f.Length / 1MB))).PadLeft(7) + "  " + $f.Name })
  $n = Select-OneRow $title $items 0 @((Get-ClmText "backup.menu.restore.hintEnter"), (Get-ClmText "backup.menu.restore.hintChoose"), (Get-ClmText "backup.menu.restore.hintEsc"), (Get-ClmText "backup.menu.restore.hintBack")) $dir
  if ($null -eq $n) { return Get-ClmText "backup.menu.restore.cancelled" }
  $zip = $list[$n].FullName
  Assert-BackupVersion $zip
  $inZip = @(Get-ZipAccounts $zip)
  if ($inZip.Count -eq 0) { return Get-ClmText "backup.menu.restore.noAccounts" @($list[$n].Name) }
  $picked = Select-Items (Get-ClmText "backup.menu.restore.pickAccounts" @($list[$n].Name)) @($inZip | ForEach-Object { $_.Label.PadRight(12) + " " + $_.Dir })
  if ($null -eq $picked) { return Get-ClmText "backup.menu.restore.cancelled" }
  $accs = @($picked | ForEach-Object { $inZip[$_] })
  $ask = Get-ClmText "backup.menu.restore.question" @((@($accs | ForEach-Object { $_.Label }) -join ", "))
  $changes = @(Get-RestoreChanges $zip $accs)
  $c = Read-PageKey { Get-PageRows $ask (Get-RestoreWarn $changes) @("o", (Get-ClmText "backup.menu.restore.confirm"), (Get-ClmText "backup.menu.restore.hintOther"), (Get-ClmText "backup.menu.restore.hintCancel")) }
  if ($c.KeyChar -ne "o") { return Get-ClmText "backup.menu.restore.cancelled" }
  return Invoke-UiWork $ask (Get-ClmText "backup.menu.restore.working") { Restore-Accounts $zip $accs -Yes }
}
