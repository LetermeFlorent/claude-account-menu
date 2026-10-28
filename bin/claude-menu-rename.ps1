function Assert-AccountName {
  param([string]$Name, [string]$Dir, $List)
  if ($Name -eq "") { throw "nom vide" }
  if ($Name.Contains(",")) { throw "la virgule est reservee a --save= et --only=" }
  if (@($List | Where-Object { $_.Dir -ne $Dir -and $_.Label -eq $Name }).Count -gt 0) { throw ("le nom " + $Name + " est deja pris") }
}

function Rename-Account {
  param($Acc, [string]$Name)
  $name = ConvertTo-AccountLabel $Name
  $list = @(Get-Accounts)
  Assert-AccountName $name $Acc.Dir $list
  $old = $Acc.Label
  if ($old -ceq $name) { return "nom inchange" }
  foreach ($a in $list) { if ($a.Dir -eq $Acc.Dir) { $a.Label = $name } }
  Save-Registry $list
  Rename-UsageEntry $old $name
  return $old + " renomme en " + $name
}

function Read-AccountName {
  param($Acc)
  Clear-Host
  Write-Host ""
  Write-Host ("  Renommer " + $Acc.Label + "  " + (Get-AccountEmail $Acc))
  Write-Host "  Seul le nom affiche change : dossier, connexion et e-mail restent les memes." -ForegroundColor DarkGray
  Write-Host ""
  return Read-Host "  Nouveau nom (Entree pour annuler)"
}

function Show-RenameMenu {
  param([int]$Pos)
  $accs = @(Get-Accounts)
  $p = Select-OneAccount $accs $Pos "Renommer un compte"
  if ($null -eq $p) { return "renommage annule" }
  Exit-UiScreen
  try { $name = Read-AccountName $accs[$p] } finally { Enter-UiScreen }
  if ([string]::IsNullOrWhiteSpace($name)) { return "renommage annule" }
  return Rename-Account $accs[$p] $name
}
