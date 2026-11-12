. Import-ClmModule claude-text, claude-account-add

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
