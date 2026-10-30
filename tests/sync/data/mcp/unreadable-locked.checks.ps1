. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")

function Invoke-LkLocked {
  param([string]$Path, [scriptblock]$Action)
  $lkHandle = [IO.File]::Open($Path, "Open", "ReadWrite", "None")
  try { & $Action } finally { $lkHandle.Dispose() }
}

$lkWaitSaved = $script:SharedWaitMs
$script:SharedWaitMs = 0
try {
  Use-Pc "LK"
  Save-Registry @([PSCustomObject]@{ Label = "c1"; Dir = ".claude" })
  Set-PcFile ".claude/a.md" "x" 1700000000

  $lkText = '{"at":1,"root":"R","files":[]}'
  [IO.File]::WriteAllText($script:DriveStatePath, $lkText)
  Invoke-LkLocked $script:DriveStatePath {
    Assert-Throws { Read-DriveState } (Get-ClmText "drive.state.unreadable" @("")) "etat verrouille : lecture en erreur, pas absent"
    $lkRun = Invoke-DriveSync
    Assert-True (-not $lkRun.Ok) "etat verrouille : synchro en echec"
    Assert-Equal 0 $script:Fake.Count "etat verrouille : rien envoye au Drive"
  }
  Assert-Equal $lkText ([IO.File]::ReadAllText($script:DriveStatePath)) "etat verrouille : fichier intact"
  Remove-Item -LiteralPath $script:DriveStatePath -Force

  $lkText = [IO.File]::ReadAllText($script:DriveConfigPath)
  Invoke-LkLocked $script:DriveConfigPath {
    Assert-Throws { Read-DriveConfig } (Get-ClmText "drive.config.unreadable" @("")) "drive.json verrouille : lecture en erreur, pas absente"
    Assert-Throws { Set-DriveAuto $false } (Get-ClmText "drive.config.unreadable" @("")) "drive.json verrouille : reglage refuse"
  }
  Assert-Equal $lkText ([IO.File]::ReadAllText($script:DriveConfigPath)) "drive.json verrouille : fichier intact"

  $lkText = '{"skills":{"a":true}}'
  [IO.File]::WriteAllText($script:SyncChoicePath, $lkText)
  Invoke-LkLocked $script:SyncChoicePath {
    Assert-Throws { Read-SyncChoice } (Get-ClmText "sync.choice.unreadable" @("")) "sync-choice.json verrouille : lecture en erreur, pas absent"
    Assert-Throws { Update-SyncChoice { param($x) Set-ChoiceCheck $x "skills" "z" $false $true } } (Get-ClmText "sync.choice.unreadable" @("")) "sync-choice.json verrouille : changement refuse"
  }
  Assert-Equal $lkText ([IO.File]::ReadAllText($script:SyncChoicePath)) "sync-choice.json verrouille : fichier intact"
  Remove-Item -LiteralPath $script:SyncChoicePath -Force

  $lkText = '{"perPc":true}'
  [IO.File]::WriteAllText($script:SyncCatalogPath, $lkText)
  Invoke-LkLocked $script:SyncCatalogPath {
    Assert-Throws { Read-SyncCatalog } (Get-ClmText "sync.catalog.unreadable" @("")) "sync-catalog.json verrouille : lecture en erreur, pas absent"
  }
  Assert-Equal $lkText ([IO.File]::ReadAllText($script:SyncCatalogPath)) "sync-catalog.json verrouille : fichier intact"
  Remove-Item -LiteralPath $script:SyncCatalogPath -Force

  $lkText = '[{"Label":"a","Dir":".claude"}]'
  [IO.File]::WriteAllText($script:RegistryPath, $lkText)
  Invoke-LkLocked $script:RegistryPath {
    $lkAccs = @(Get-Accounts)
    Assert-Equal "compte1" $lkAccs[0].Label "accounts.json verrouille : comptes par defaut, pas la liste lue"
    Assert-Throws { Save-Registry @([PSCustomObject]@{ Label = "x"; Dir = ".claude-x" }) } (Get-ClmText "accounts.registry.unreadable") "accounts.json verrouille : ecriture refusee"
  }
  Assert-Equal $lkText ([IO.File]::ReadAllText($script:RegistryPath)) "accounts.json verrouille : fichier intact"
  Assert-Equal "a" ((@(Get-Accounts) | ForEach-Object { $_.Label }) -join "|") "accounts.json deverrouille : liste relue"
} finally {
  $script:SharedWaitMs = $lkWaitSaved
  Restore-FakeDrive
  Remove-Item Function:\Invoke-LkLocked
}
