$now = [long]10000000
$st = New-WatchState $now
Assert-Equal "" (Get-DriveWatchAction $st ($now + 1000)) "rien a faire au depart"
Assert-Equal "check" (Get-DriveWatchAction $st ($now + 30000)) "Drive regarde toutes les 30 s"

Add-WatchLocalChange $st ($now + 100)
Add-WatchLocalChange $st ($now + 900)
Assert-Equal ($now + 100) $st.LocalFirst "premier changement garde"
Assert-Equal "" (Get-DriveWatchAction $st ($now + 2000)) "changement local : attente du calme"
Assert-Equal "pass" (Get-DriveWatchAction $st ($now + 2900)) "changement local calme : synchro"

$ok = New-SyncResult
$ok.Ok = $true
Assert-True (-not (Complete-WatchPass $st $ok $false ($now + 3000))) "passe ordinaire : aucune session a fermer"
Assert-Equal 0 $st.LocalFirst "passe faite : changements oublies"
Assert-Equal ($now + 3000) $st.RemoteAt "passe faite : Drive regarde"
Add-WatchLocalChange $st ($now + 4000)
Assert-Equal "" (Get-DriveWatchAction $st ($now + 10000)) "30 s au moins entre deux synchros"
Assert-Equal "pass" (Get-DriveWatchAction $st ($now + 33000)) "changement synchronise 30 s apres la passe"

$st = New-WatchState $now
for ($t = 0; $t -le 30000; $t += 1000) { Add-WatchLocalChange $st ($now + $t) }
Assert-Equal "pass" (Get-DriveWatchAction $st ($now + 30000)) "changements sans arret : synchro quand meme apres 30 s"

$st = New-WatchState $now
$st.Due = $true
Assert-Equal "pass" (Get-DriveWatchAction $st $now) "nouveaute sur le Drive : synchro tout de suite"
$busy = New-SyncResult
$busy.Busy = $true
Assert-True (-not (Complete-WatchPass $st $busy $false $now)) "synchro occupee : rien a fermer"
Assert-True $st.Due "synchro occupee : toujours a faire"
Assert-Equal "" (Get-DriveWatchAction $st ($now + 4000)) "synchro occupee : attente"
Assert-Equal "pass" (Get-DriveWatchAction $st ($now + 5000)) "synchro occupee : nouvel essai a 5 s"
$fail = New-SyncResult
$fail.Error = "panne"
$null = Complete-WatchPass $st $fail $false $now
Assert-True $st.Due "panne : synchro a refaire"
Assert-Equal "" (Get-DriveWatchAction $st ($now + 59000)) "panne : attente"
Assert-Equal "pass" (Get-DriveWatchAction $st ($now + 60000)) "panne : nouvel essai a 60 s"
$left = New-SyncResult
$left.Left = 3
$null = Complete-WatchPass $st $left $false $now
Assert-True $st.Due "fichiers restants : synchro a refaire"

$st = New-WatchState $now
$st.Ended["a.end"] = ".claude"
$st.EndedSince = $now
Assert-Equal "final" (Get-DriveWatchAction $st $now) "session finie : derniere synchro tout de suite"
Assert-True (Complete-WatchPass $st $ok $true $now) "derniere synchro reussie : session fermee"
Assert-True (-not (Complete-WatchPass $st $fail $true ($now + 1000))) "derniere synchro en panne : session gardee"
Assert-True (-not (Complete-WatchPass $st $busy $true ($now + 1000))) "derniere synchro occupee : session gardee"
Assert-True (Complete-WatchPass $st $fail $true ($now + 600000)) "panne depuis 10 min : session fermee quand meme"

$st = New-WatchState $now
$st.Fs = @{ Blind = $true }
$st.PassAt = $now
Assert-Equal "" (Get-DriveWatchAction $st ($now + 20000)) "sans surveillance : attente"
Assert-Equal "pass" (Get-DriveWatchAction $st ($now + 60000)) "sans surveillance : synchro chaque minute"
$st.Fs = @{ Blind = $false }
Assert-Equal "check" (Get-DriveWatchAction $st ($now + 60000)) "avec surveillance : simple regard sur le Drive"

$st = New-WatchState $now
$st.Ended["a.end"] = ".claude"
$st.Ended["b.end"] = ".claude"
$st.Ended["c.end"] = ".claude-compte2"
$st.Ended["d.end"] = ""
$st.LiveDirs = @{ ".claude-compte2" = $true }
Assert-Equal ".claude" ((Get-WatchClosedDirs $st) -join "|") "presence retiree une fois, pas pour un compte encore ouvert"
Assert-True (Test-WatchActive $st) "sessions finies : veilleur actif"
$st.Ended.Clear()
Assert-True (-not (Test-WatchActive $st)) "plus de session : veilleur arrete"
$st.Live = 1
Assert-True (Test-WatchActive $st) "session ouverte : veilleur actif"
