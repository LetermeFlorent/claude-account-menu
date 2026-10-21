function New-AccountSlot {
  param([string]$Label)
  $list = @(Get-Accounts)
  $n = $list.Count + 1
  while (Test-Path -LiteralPath (Join-Path $script:HomeDir (".claude-compte" + $n))) { $n++ }
  if ([string]::IsNullOrWhiteSpace($Label)) { $Label = "compte" + $n }
  $acc = [PSCustomObject]@{ Label = $Label.Trim(); Dir = ".claude-compte" + $n }
  Repair-SharedLinks $acc
  $dir = Get-AccountPath $acc
  $settings = [IO.Path]::Combine($script:HomeDir, ".claude", "settings.json")
  if (Test-Path -LiteralPath $settings) { Copy-Item -LiteralPath $settings -Destination $dir }
  $cfg = [PSCustomObject]@{ hasCompletedOnboarding = $true; lastOnboardingVersion = (Get-ClaudeVersion) }
  $cfg | ConvertTo-Json | Set-Content -LiteralPath (Get-AccountConfigFile $acc) -Encoding UTF8
  Save-Registry ($list + $acc)
  return $acc
}

function Show-AddAccountHelp {
  Clear-Host
  Write-Host ""
  Write-Host "  Ajouter un compte Claude"
  Write-Host "  Le navigateur va s'ouvrir sur la page de connexion." -ForegroundColor DarkGray
  Write-Host "  Si claude.ai y est deja connecte sur un autre compte, copie le lien affiche" -ForegroundColor DarkGray
  Write-Host "  dans une fenetre privee, sinon c'est cet autre compte qui sera enregistre." -ForegroundColor DarkGray
  Write-Host ""
}

function Add-Account {
  param($Label = $null)
  Show-AddAccountHelp
  if ($null -ne $Label) { return Connect-NewAccount $Label }
  $label = Read-Host "  Nom du compte (Entree pour le nom par defaut, q pour annuler)"
  if ($label -eq "q") { return "ajout annule" }
  return Connect-NewAccount $label
}

function Connect-NewAccount {
  param([string]$Label)
  $acc = New-AccountSlot $Label
  Invoke-AsAccount $acc @("auth", "login") | Out-Host
  $mail = Get-AccountEmail $acc
  if ($mail -eq "") { return $acc.Label + " cree, mais non connecte : relance-le pour faire /login" }
  return $acc.Label + " ajoute : " + $mail
}
