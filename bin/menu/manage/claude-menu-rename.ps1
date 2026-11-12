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
