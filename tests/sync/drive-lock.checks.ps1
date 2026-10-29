try { . (Join-Path $bin "claude-drive-lock.ps1") } catch { Assert-True $false ("module de verrou charge : " + $_.Exception.Message) }

function Clear-OnceStamp {
  [IO.File]::Delete((Get-StatePath "test-once.done"))
}

function Get-ErrorOf {
  param([scriptblock]$Action)
  try { $null = & $Action } catch { return $_ }
  return $null
}

$script:OnceRan = 0
Clear-OnceStamp
Assert-Equal "done" (Invoke-MachineOnce "test-once" 0 { $script:OnceRan++ }) "une fois : fait"
Assert-Equal 1 $script:OnceRan "une fois : action lancee"

$held = Open-MachineLock "test-once"
try { $result = Invoke-MachineOnce "test-once" 0 { $script:OnceRan++ } } finally { Close-MachineLock $held }
Assert-Equal "left" $result "une fois : verrou tenu, laisse"
Assert-Equal 1 $script:OnceRan "une fois : verrou tenu, action jamais lancee"
Assert-True (-not (Test-MachineLockHeld "test-once")) "verrou rendu : libre"

Clear-OnceStamp
Write-LockDone "test-once" ((Get-LockNow) + 60000)
Assert-Equal "skipped" (Invoke-MachineOnce "test-once" 0 { $script:OnceRan++ }) "une fois : fait par un autre apres la demande"
Assert-Equal 1 $script:OnceRan "une fois : saute, action jamais lancee"
Assert-Equal "done" (Invoke-MachineOnce "test-once" 0 { $script:OnceRan++ } -Always) "une fois : -Always passe outre"
Assert-Equal 2 $script:OnceRan "une fois : -Always lance l'action"

Clear-OnceStamp
Write-LockDone "test-once" ((Get-LockNow) - 60000)
Assert-Equal "done" (Invoke-MachineOnce "test-once" 0 { $script:OnceRan++ }) "une fois : trace plus ancienne que la demande, fait"
Assert-Equal 3 $script:OnceRan "une fois : trace ancienne, action lancee"

Clear-OnceStamp
$before = Get-LockNow
$null = Invoke-MachineOnce "test-once" 0 { $false }
Assert-True (-not (Test-LockDoneSince "test-once" $before)) "une fois : sortie fausse, aucune trace"
$null = Invoke-MachineOnce "test-once" 0 { $true }
Assert-True (Test-LockDoneSince "test-once" $before) "une fois : sortie vraie, trace ecrite"
Clear-OnceStamp

Assert-Equal "ok" (Invoke-WithMachineLock "test-with" 0 { "ok" }) "verrou : sortie de l'action rendue"
$held = Open-MachineLock "test-with"
try {
  Assert-True (Test-MachineLockHeld "test-with") "verrou tenu : vu comme tenu"
  Assert-Throws { Invoke-WithMachineLock "test-with" 0 { "ok" } } "laissee a un autre clm" "verrou tenu : erreur par defaut"
  $err = Get-ErrorOf { Invoke-WithMachineLock "test-with" 0 { "ok" } }
  Assert-True (Test-LeftToOtherClm $err) "verrou tenu : erreur reconnue"
  Assert-Throws { Invoke-WithMachineLock "test-with" 0 { "ok" } "occupe ici" } "occupe ici" "verrou tenu : texte donne"
  $err = Get-ErrorOf { Invoke-WithMachineLock "test-with" 0 { "ok" } "occupe ici" }
  Assert-True (-not (Test-LeftToOtherClm $err)) "verrou tenu : texte donne, pas l'erreur par defaut"
} finally { Close-MachineLock $held }
Assert-True (-not (Test-MachineLockHeld "test-with")) "verrou rendu : plus tenu"
