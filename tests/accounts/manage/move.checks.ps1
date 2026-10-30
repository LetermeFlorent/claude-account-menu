. (Join-Path $bin "menu/manage/claude-menu-rename.ps1")
. (Join-Path $bin "menu/manage/claude-menu-remove.ps1")
. (Join-Path $bin "cli/claude-cli.ps1")

$moveSaved = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $moveSaved = [IO.File]::ReadAllBytes($script:RegistryPath) }

function Get-MoveOrder { return (@(Get-Accounts) | ForEach-Object { $_.Label }) -join "|" }

try {
  Save-Registry @(
    [PSCustomObject]@{ Label = "compte1"; Dir = ".claude" },
    [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" },
    [PSCustomObject]@{ Label = "perso"; Dir = ".claude-compte3" }
  )
  $accs = @(Get-Accounts)
  Assert-Equal (Get-ClmText "accounts.move.done" @("perso", 1)) (Move-Account $accs[2] 1) "ordre : compte monte en tete"
  Assert-Equal "perso|compte1|Pro" (Get-MoveOrder) "ordre : les autres descendent d'un rang"
  Assert-Equal (Get-ClmText "accounts.move.done" @("perso", 3)) (Move-Account $accs[2] 3) "ordre : compte descendu en bas"
  Assert-Equal "compte1|Pro|perso" (Get-MoveOrder) "ordre : retour a l'ordre de depart"
  Assert-Equal (Get-ClmText "accounts.move.alreadyAt" @("Pro", 2)) (Move-Account $accs[1] 2) "ordre : meme rang, rien a faire"
  Assert-Equal ".claude-compte2" (@(Get-Accounts)[1]).Dir "ordre : dossiers suivent leur compte"

  foreach ($bad in @(0, 4, -1)) {
    $err = ""
    try { $null = Move-Account $accs[0] $bad } catch { $err = $_.Exception.Message }
    Assert-Equal (Get-ClmText "accounts.move.outOfRange" @($bad, 3)) $err "ordre : rang $bad refuse"
  }
  $err = ""
  try { $null = Move-Account ([PSCustomObject]@{ Label = "fantome"; Dir = ".claude-compte9" }) 1 } catch { $err = $_.Exception.Message }
  Assert-Equal (Get-ClmText "accounts.move.unknown" @("fantome")) $err "ordre : compte absent refuse"
  Assert-Equal "compte1|Pro|perso" (Get-MoveOrder) "ordre : refus sans effet sur le registre"

  Assert-Equal 0 (Invoke-CliCommand (Get-CliCommand @("--move", "perso", "2")) @() 6>$null) "--move : reussi"
  Assert-Equal "compte1|perso|Pro" (Get-MoveOrder) "--move : rang ecrit"
  Assert-Equal 1 (Invoke-CliCommand (Get-CliCommand @("--move", "perso")) @() 6>$null) "--move sans rang : echec"
  Assert-Equal 1 (Invoke-CliCommand (Get-CliCommand @("--move", "perso", "haut")) @() 6>$null) "--move rang non numerique : echec"
  Assert-Equal 1 (Invoke-CliCommand (Get-CliCommand @("--move", "inconnu", "1")) @() 6>$null) "--move compte inconnu : echec"
  Assert-Equal "compte1|perso|Pro" (Get-MoveOrder) "--move refuse : ordre garde"
} finally {
  if ($null -ne $moveSaved) { [IO.File]::WriteAllBytes($script:RegistryPath, $moveSaved) } else { Remove-Item -LiteralPath $script:RegistryPath -Force -ErrorAction SilentlyContinue }
}
