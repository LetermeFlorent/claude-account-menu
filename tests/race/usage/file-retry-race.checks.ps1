$frPath = New-SandboxFile "file-retry/shared.json" '{"n":1}'

function Wait-FrFake {
  param([int]$Milliseconds)
  $script:FrSleeps++
  if ($script:FrSleeps -ge $script:FrLockedFor) { $script:FrHandle.Dispose() }
}

Set-Alias -Name Start-Sleep -Value Wait-FrFake

function Invoke-FrLocked {
  param([int]$LockedFor, [scriptblock]$Action)
  $script:FrSleeps = 0
  $script:FrLockedFor = $LockedFor
  $script:FrHandle = [IO.File]::Open($frPath, "Open", "ReadWrite", "None")
  try { return & $Action } finally { $script:FrHandle.Dispose() }
}

try {
  $frTries = 0
  $frText = Invoke-FrLocked 2 { Invoke-FileRetry { $script:frTries++; [IO.File]::ReadAllText($frPath) } }
  Assert-Equal '{"n":1}' $frText "fichier bloque 2 essais : le 3e essai lit le fichier"
  Assert-Equal 3 $frTries "fichier bloque 2 essais : 3 essais"

  $frTries = 0
  Assert-Throws { Invoke-FrLocked 99 { Invoke-FileRetry { $script:frTries++; [IO.File]::ReadAllText($frPath) } } } "" "fichier bloque 3 essais et plus : erreur remontee"
  Assert-Equal 3 $frTries "fichier bloque 3 essais et plus : arret apres exactement 3 essais"

  $frTries = 0
  Assert-Throws { Invoke-FileRetry { $script:frTries++; [IO.File]::ReadAllText($frPath + ".absent") } } "" "fichier absent : erreur remontee"
  Assert-Equal 1 $frTries "fichier absent : pas de nouvel essai"

  Assert-Equal '{"n":1}' (Invoke-FrLocked 2 { Read-SharedText $frPath }) "lecture partagee bloquee 2 essais : lue au 3e"
  Assert-Equal 2 $script:FrSleeps "lecture partagee bloquee 2 essais : 2 pauses"
  Assert-Throws { Invoke-FrLocked 99 { Read-SharedText $frPath } } "" "lecture partagee bloquee 3 essais : erreur remontee"
  Assert-Equal 2 $script:FrSleeps "lecture partagee bloquee 3 essais : 3 essais, 2 pauses"

  Invoke-FrLocked 2 { Write-TextFileAtomic $frPath '{"n":2}' }
  Assert-Equal '{"n":2}' ([IO.File]::ReadAllText($frPath)) "ecriture bloquee 2 essais : fichier remplace au 3e"
  if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
    Assert-Throws { Invoke-FrLocked 99 { Write-TextFileAtomic $frPath '{"n":3}' } } "" "ecriture bloquee 3 essais : erreur remontee"
    Assert-Equal 2 $script:FrSleeps "ecriture bloquee 3 essais : 3 essais, 2 pauses"
    Assert-Equal '{"n":2}' ([IO.File]::ReadAllText($frPath)) "ecriture bloquee 3 essais : fichier intact"
  }
  Assert-Equal 0 @(Get-ChildItem -LiteralPath (Split-Path $frPath) -Filter "*.tmp").Count "ecriture bloquee : aucun temporaire laisse"
} finally {
  Remove-Item Alias:\Start-Sleep, Function:\Wait-FrFake, Function:\Invoke-FrLocked
}
