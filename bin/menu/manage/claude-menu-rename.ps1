. Import-ClmModule claude-text
function Assert-AccountName {
  param([string]$Name, [string]$Dir, $List)
  if ($Name -eq "") { throw (Get-ClmText "accounts.rename.empty") }
  if ($Name.Contains(",")) { throw (Get-ClmText "accounts.rename.comma") }
  if (@($List | Where-Object { $_.Dir -ne $Dir -and $_.Label -eq $Name }).Count -gt 0) { throw (Get-ClmText "accounts.rename.taken" @($Name)) }
}

function Rename-Account {
  param($Acc, [string]$Name)
  $name = ConvertTo-AccountLabel $Name
  $list = @(Get-Accounts)
  Assert-AccountName $name $Acc.Dir $list
  $old = $Acc.Label
  if ($old -ceq $name) { return Get-ClmText "accounts.rename.unchanged" }
  foreach ($a in $list) { if ($a.Dir -eq $Acc.Dir) { $a.Label = $name } }
  Save-Registry $list
  Rename-UsageEntry $old $name
  return Get-ClmText "accounts.rename.done" @($old, $name)
}

function Read-AccountName {
  param($Acc)
  Clear-Host
  Write-Host ""
  Write-Host ("  " + (Get-ClmText "accounts.rename.header" @($Acc.Label)) + "  " + (Get-AccountEmail $Acc))
  Write-Host ("  " + (Get-ClmText "accounts.rename.note")) -ForegroundColor DarkGray
  Write-Host ""
  return Read-Host ("  " + (Get-ClmText "accounts.rename.prompt"))
}

function Show-RenameMenu {
  param([int]$Pos)
  $accs = @(Get-Accounts)
  $p = Select-OneAccount $accs $Pos (Get-ClmText "accounts.rename.menuTitle")
  if ($null -eq $p) { return Get-ClmText "accounts.rename.cancelled" }
  Exit-UiScreen
  try { $name = Read-AccountName $accs[$p] } finally { Enter-UiScreen }
  if ([string]::IsNullOrWhiteSpace($name)) { return Get-ClmText "accounts.rename.cancelled" }
  return Rename-Account $accs[$p] $name
}
