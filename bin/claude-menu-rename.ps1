function Rename-Account {
  param($Acc, [string]$Name)
  $name = $Name.Trim()
  if ($name -eq "") { throw "nom vide" }
  if ($name.Contains(",")) { throw "la virgule est reservee a --save= et --only=" }
  $list = @(Get-Accounts)
  if (@($list | Where-Object { $_.Dir -ne $Acc.Dir -and $_.Label -eq $name }).Count -gt 0) { throw ("le nom " + $name + " est deja pris") }
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
