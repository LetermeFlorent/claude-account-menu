. Import-ClmModule claude-text
function Remove-LinkOrTree {
  param([string]$Path)
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    if ($script:OsName -eq "Windows" -and $item.PSIsContainer) { [IO.Directory]::Delete($item.FullName, $false) }
    else { [IO.File]::Delete($item.FullName) }
    return
  }
  if ($item.PSIsContainer) {
    foreach ($c in @(Get-ChildItem -LiteralPath $item.FullName -Force)) { Remove-LinkOrTree $c.FullName }
    [IO.Directory]::Delete($item.FullName, $false)
    return
  }
  try { [IO.File]::Delete($item.FullName); return } catch [UnauthorizedAccessException] { Write-Verbose $_.Exception.Message }
  $item.Attributes = [IO.FileAttributes]::Normal
  [IO.File]::Delete($item.FullName)
}

function Test-ErasableDir {
  param([string]$Dir)
  return $Dir -match '^\.claude-[^\\/]+$' -and $Dir -notmatch '^\.claude-\.+$'
}

function Remove-Account {
  param($Acc, [bool]$Erase)
  $list = @(Get-Accounts | Where-Object { $_.Dir -ne $Acc.Dir })
  if ($list.Count -eq 0) { throw (Get-ClmText "accounts.remove.last") }
  $dir = Get-AccountPath $Acc
  $zip = $null
  if ($Erase) {
    if (-not (Test-ErasableDir $Acc.Dir)) { throw (Get-ClmText "accounts.remove.neverErased" @($Acc.Dir)) }
    if (Test-Path -LiteralPath $dir) { $zip = Save-Accounts "" @($Acc) }
  }
  Save-Registry $list
  $msg = Get-ClmText "accounts.remove.removed" @($Acc.Label)
  if (-not $Erase -or -not (Test-Path -LiteralPath $dir)) { return $msg }
  try {
    if ($script:OsName -eq "MacOS") { Remove-KeychainCredential $dir }
    Remove-LinkOrTree $dir
  } catch {
    return Get-ClmText "accounts.remove.eraseIncomplete" @($Acc.Label, $dir, $_.Exception.Message)
  }
  return Get-ClmText "accounts.remove.erased" @($Acc.Label, $zip)
}

function Format-RemoveItem {
  param($Acc)
  return ($Acc.Label.PadRight(12) + " " + $Acc.Dir.PadRight(18) + " " + (Get-AccountEmail $Acc)).TrimEnd()
}

function Select-OneAccount {
  param($Accs, [int]$Pos, [string]$Title)
  $items = @(foreach ($a in $Accs) { Format-RemoveItem $a })
  return Select-OneRow $Title $items $Pos @((Get-ClmText "accounts.footer.enterOrDigit"), (Get-ClmText "accounts.footer.choose"), (Get-ClmText "accounts.footer.escape"), (Get-ClmText "accounts.footer.cancel"))
}

function Get-RemoveBody {
  param($Acc, [bool]$Erasable)
  $rows = New-Object System.Collections.Generic.List[object]
  $rows.Add((New-TextRow ("  1  " + (Get-ClmText "accounts.remove.optionKeep")) $script:Ink.Text))
  if ($Erasable) {
    $rows.Add((New-TextRow ("  2  " + (Get-ClmText "accounts.remove.optionErase")) $script:Ink.Alert))
    $rows.Add((New-TextRow ("     " + (Get-ClmText "accounts.remove.archiveNote")) $script:Ink.Dim))
    if ($script:OsName -eq "MacOS") { $rows.Add((New-TextRow ("     " + (Get-ClmText "accounts.remove.keychainNote")) $script:Ink.Dim)) }
  } else {
    $rows.Add((New-TextRow ("     " + (Get-ClmText "accounts.remove.neverErasedHere" @($Acc.Dir))) $script:Ink.Dim))
  }
  return ,$rows
}

function Show-RemoveMenu {
  param([int]$Pos)
  $accs = @(Get-Accounts)
  if ($accs.Count -le 1) { return Get-ClmText "accounts.remove.impossible" }
  $p = Select-OneAccount $accs $Pos (Get-ClmText "accounts.remove.title")
  if ($null -eq $p) { return Get-ClmText "accounts.remove.cancelled" }
  $acc = $accs[$p]
  $erasable = Test-ErasableDir $acc.Dir
  $title = Get-ClmText "accounts.remove.confirmTitle" @($acc.Label, $acc.Dir)
  while ($true) {
    $k = Read-PageKey { Get-PageRows $title (Get-RemoveBody $acc $erasable) @((Get-ClmText "accounts.footer.escape"), (Get-ClmText "accounts.footer.cancel")) }
    if ($k.Key -eq "Escape" -or $k.KeyChar -eq "q") { return Get-ClmText "accounts.remove.cancelled" }
    if ($k.KeyChar -eq "1") { return Remove-Account $acc $false }
    if ($k.KeyChar -eq "2" -and $erasable) { return Invoke-UiWork $title (Get-ClmText "accounts.remove.working") { Remove-Account $acc $true } }
  }
}
