$lockAcc = [PSCustomObject]@{ Label = "lk"; Dir = ".claude-credlock" }
$lockFold = @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" }
$lockKeys = New-SyncKeys ([byte[]](60..91)) ([byte[]](1..16)) 600000
$lockWaitSaved = $script:CredLockWaitMs
$script:CredLockWaitMs = 0
$lockHeld = Open-MachineLock "drive-creds"
$lockErr = ""
$lockOut = @()
try { $lockOut = @(Sync-AccountCredential $lockAcc $lockFold @{} $lockKeys *>&1) } catch { $lockErr = $_.Exception.Message }
finally { Close-MachineLock $lockHeld; $script:CredLockWaitMs = $lockWaitSaved }
Assert-Equal "" $lockErr "jetons sous verrou tenu : aucune erreur"
Assert-Equal 1 $lockOut.Count "jetons sous verrou tenu : rien d'affiche"
Assert-Equal "left" ("" + $lockOut[0]) "jetons sous verrou tenu : laisses a un autre clm"
