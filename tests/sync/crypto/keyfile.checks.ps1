if (-not (Test-Path Function:\Invoke-DriveSetup)) { . (Join-Path $bin "claude-sync-passphrase.ps1") }
. (Join-Path (Split-Path -Parent $PSScriptRoot) "fake-drive.ps1")
$kfSaved = @($script:SyncKeyIterations, $script:SyncKeyMinIterations, ${function:Read-SyncPassText})
$script:SyncKeyIterations = 1000
$script:SyncKeyMinIterations = 1000
$script:KfAnswers = New-Object Collections.Queue
$script:KfPrompts = 0
function Read-SyncPassText { param([string]$Prompt) $script:KfPrompts++; return $script:KfAnswers.Dequeue() }
function Set-KfAnswers { param([string[]]$Texts) $script:KfAnswers.Clear(); foreach ($t in $Texts) { $script:KfAnswers.Enqueue($t) } }
$kfPass = "phrase de test bien longue"
try {
  Use-Pc "PCK"
  Remove-SyncKeys
  $script:FakeRootFiles.Clear()
  $kfFolders = Get-DriveFolders
  Set-KfAnswers @("court", "court")
  Assert-Throws { Set-SyncPassphrase } (Get-ClmText "sync.pass.short") "phrase trop courte refusee"
  Set-KfAnswers @($kfPass, "une autre phrase longue")
  Assert-Throws { Set-SyncPassphrase } (Get-ClmText "sync.pass.differ") "deux saisies differentes refusees"
  Assert-True (-not (Test-SyncKeyStored) -and $script:FakeRootFiles.Count -eq 0) "saisie refusee : rien d'enregistre"
  Set-KfAnswers @($kfPass, $kfPass)
  $null = Set-SyncPassphrase
  $kfFile = $script:FakeRootFiles[$script:SyncKeyFileName]
  Assert-True ($null -ne $kfFile -and (Test-SyncKeyStored)) "premier PC : fichier de cle cree et cle gardee"
  Assert-Equal (Get-SyncKeys).Check $kfFile.Props["check"] "premier PC : valeur de controle publiee"
  Assert-Equal "1000" $kfFile.Props["iterations"] "premier PC : iterations publiees"
  Assert-True (-not ([IO.File]::ReadAllText($script:SyncKeyStorePath)).Contains($kfPass)) "phrase jamais gardee sur le PC"
  Assert-True (-not [Text.Encoding]::UTF8.GetString($kfFile.Bytes).Contains($kfPass)) "phrase jamais envoyee au Drive"
  $kfCheck = (Get-SyncKeys).Check

  Use-Pc "PCL"
  Remove-SyncKeys
  Set-KfAnswers @("mauvaise phrase de test")
  Assert-Throws { Set-SyncPassphrase } (Get-ClmText "sync.pass.wrong") "second PC : mauvaise phrase signalee"
  Assert-True (-not (Test-SyncKeyStored)) "second PC : mauvaise phrase non gardee"
  Set-KfAnswers @($kfPass)
  $null = Set-SyncPassphrase
  Assert-Equal $kfCheck (Get-SyncKeys).Check "second PC : meme cle avec la bonne phrase"
  Assert-Equal 0 $script:KfAnswers.Count "second PC : une seule saisie"

  $kfFile.Props["iterations"] = "999"
  Remove-SyncKeys
  $script:KfPrompts = 0
  Set-KfAnswers @($kfPass)
  Assert-Throws { Set-SyncPassphrase } (Get-ClmText "sync.key.weak") "iterations sous le minimum refusees"
  Assert-Equal 0 $script:KfPrompts "iterations faibles : refus avant la saisie"
  $kfFile.Props["iterations"] = "1000"
  $kfFile.Props["v"] = "9"
  Assert-Throws { Set-SyncPassphrase } (Get-ClmText "sync.key.weak") "version inconnue refusee"
  $kfFile.Props["v"] = "1"

  Set-KfAnswers @($kfPass)
  $null = Set-SyncPassphrase
  Assert-SyncKeysMatch $kfFolders (Get-SyncKeys)
  $script:Passed++
  $script:FakeRootFiles.Clear()
  Assert-SyncKeysMatch $kfFolders (Get-SyncKeys)
  Assert-Equal $kfCheck $script:FakeRootFiles[$script:SyncKeyFileName].Props["check"] "fichier de cle efface : republie"

  Set-KfAnswers @("nouvelle phrase pour tous", "nouvelle phrase pour tous")
  $null = Reset-SyncPassphrase
  $kfNew = Get-SyncKeys
  Assert-True ($kfNew.Check -ne $kfCheck) "nouvelle phrase : nouvelle cle"
  Assert-Equal $kfNew.Check $script:FakeRootFiles[$script:SyncKeyFileName].Props["check"] "nouvelle phrase : fichier de cle remplace"
  Use-Pc "PCK"
  Assert-Throws { Assert-SyncKeysMatch $kfFolders (Get-SyncKeys) } (Get-ClmText "sync.key.changed") "autre PC : phrase changee signalee"
  $null = Clear-SyncPassphrase
  Assert-True (-not (Test-SyncKeyStored)) "phrase oubliee sur ce PC"
} finally {
  $script:SyncKeyIterations, $script:SyncKeyMinIterations = $kfSaved[0..1]
  Set-Item -Path function:Read-SyncPassText -Value $kfSaved[2]
  Restore-FakeDrive
}
