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
