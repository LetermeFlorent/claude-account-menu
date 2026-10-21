function Get-JobSegsText {
  param($Row)
  $t = ""
  foreach ($s in $Row) { $t += $s[0] }
  return $t
}

function New-FakeDriveLoader {
  param($Result, [bool]$Done = $true, [string]$Err = $null)
  $q = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  if ($Done) { $q.Enqueue(@(0, $Result, $Err)) }
  return @{ Ps = $null; Ctl = @{ Done = $Done; Error = $null }; Queue = $q }
}

$keptJob = $script:DriveJob
$at = [DateTimeOffset]::new(2026, 10, 14, 14, 32, 0, [TimeSpan]::Zero).ToUnixTimeSeconds()
$hm = [DateTimeOffset]::FromUnixTimeSeconds($at).LocalDateTime.ToString("HH:mm")

Assert-Equal "" (Get-DriveTag (New-DriveJob $false 0))[0] "Drive non connecte : rien dans l'en-tete"
Assert-Equal "" (Get-DriveTag $null)[0] "pas de tache : rien dans l'en-tete"
Assert-Equal "sync jamais" (Get-DriveTag (New-DriveJob $true 0))[0] "jamais synchronise"
$job = New-DriveJob $true $at
Assert-Equal ("sync " + $hm) (Get-DriveTag $job)[0] "heure de la derniere synchro"
$job.Loader = New-FakeDriveLoader $null $false
$job.Ctl = @{ Stop = $false; Progress = "" }
Assert-Equal "sync..." (Get-DriveTag $job)[0] "synchro en cours sans progression"
$job.Ctl.Progress = "12/5508"
Assert-Equal "sync 12/5508" (Get-DriveTag $job)[0] "progression dans l'en-tete"
Assert-True (Step-DriveJob $job) "progression nouvelle : ecran a redessiner"
Assert-True (-not (Step-DriveJob $job)) "progression inchangee : rien a redessiner"
$job.Failed = $true
$job.Loader = $null
Assert-Equal "sync erreur" (Get-DriveTag $job)[0] "erreur dans l'en-tete"
Assert-Equal $script:Ink.Alert (Get-DriveTag $job)[1] "erreur en couleur d'alerte"

$job = New-DriveJob $true 0
$job.Ctl = @{ Stop = $false; Progress = "3/3" }
$job.Loader = New-FakeDriveLoader @{ Ok = $true; Error = ""; At = $at; Up = 3; Down = 0; Deleted = 0; Conflicts = 0; Left = 0; Away = @{ ".claude-compte2" = "MAC" } }
Assert-True (Step-DriveJob $job) "fin de synchro : ecran a redessiner"
Assert-Null $job.Loader "fin de synchro : tache liberee"
Assert-Equal $at $job.Last "fin de synchro : heure gardee"
Assert-Null $job.Notice "synchro automatique reussie : pas de message"
$job.Notify = $true
$job.Loader = New-FakeDriveLoader @{ Ok = $true; Error = ""; At = $at; Up = 1; Down = 2; Deleted = 0; Conflicts = 0; Left = 0; Away = @{} }
$null = Step-DriveJob $job
Assert-Equal "synchro Drive : 1 envoyes, 2 recus, 0 supprimes, 0 conflits" $job.Notice "synchro demandee : resultat affiche"
$job.Notice = $null
$job.Loader = New-FakeDriveLoader @{ Ok = $false; Error = "synchro bloquee : 30 suppressions prevues, verifier puis lancer clm --sync --force"; At = 0 }
$null = Step-DriveJob $job
Assert-True $job.Failed "garde-fou : erreur"
Assert-Equal "synchro Drive : synchro bloquee : 30 suppressions prevues, verifier puis lancer clm --sync --force" $job.Notice "erreur toujours affichee"
Assert-Equal $at $job.Last "erreur : derniere synchro reussie gardee"
$job.Loader = New-FakeDriveLoader @{ Ok = $true; Error = ""; At = $at; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Left = 0; Away = @{} }
$null = Step-DriveJob $job
Assert-True (-not $job.Failed) "synchro reussie : erreur effacee"
$job.Loader = New-FakeDriveLoader $null $true "panne"
$null = Step-DriveJob $job
Assert-True $job.Failed "exception dans la tache : erreur"
$waitJob = New-DriveJob $true $at
$waitJob.Ctl = @{ Stop = $false; Progress = "" }
$waitJob.Loader = New-FakeDriveLoader @{ Ok = $false; Error = "une autre synchro Drive est en cours"; Busy = $true; At = 0 }
$null = Step-DriveJob $waitJob
Assert-True (-not $waitJob.Failed) "synchro prise par une autre fenetre : pas une erreur"
Assert-Equal "sync attente" (Get-DriveTag $waitJob)[0] "synchro prise par une autre fenetre : en attente"
Assert-Equal $script:Ink.Dim (Get-DriveTag $waitJob)[1] "attente en couleur discrete"
Assert-Null $waitJob.Notice "attente automatique : pas de message"

$script:Started = 0
$keptLoader = (Get-Item "function:Start-UsageLoader").ScriptBlock
function Start-UsageLoader {
  param($Accounts, [string]$Source, [string]$Reader, [switch]$Hold)
  $script:Started++
  $script:LoaderArgs = @($Accounts, $Source, $Reader)
  $l = New-FakeDriveLoader $null $false
  $l.Ctl.Go = New-Object Threading.ManualResetEventSlim((-not $Hold))
  return $l
}
try {
  Assert-Equal "  Drive non connecte : clm --drive-login" (Request-DriveSync (New-DriveJob $false 0))[0] "touche y sans Drive"
  $job = New-DriveJob $true 0
  Assert-Equal "  synchro Drive lancee" (Request-DriveSync $job)[0] "touche y au repos : synchro lancee"
  Assert-Equal 1 $script:Started "touche y : une tache lancee"
  Assert-True $job.Notify "touche y : resultat annonce a la fin"
  Assert-Equal "Invoke-DriveSync" $script:LoaderArgs[2] "tache : synchro complete"
  Assert-True ($script:LoaderArgs[1].EndsWith("claude-drive-sync.ps1")) "tache : module de synchro charge"
  Assert-True ([object]::ReferenceEquals($job.Ctl, @($script:LoaderArgs[0])[0])) "tache : controle partage pour l'arret"
  Assert-Equal "  synchro Drive deja en cours" (Request-DriveSync $job)[0] "touche y pendant une synchro"
  Assert-Equal 1 $script:Started "touche y pendant une synchro : rien de plus"
  Assert-True (-not (Step-DriveJob $waitJob ($waitJob.RetryAt - 1))) "attente : pas de nouvel essai avant le delai"
  Assert-True (Step-DriveJob $waitJob $waitJob.RetryAt) "attente : nouvel essai apres le delai"
  Assert-Equal 2 $script:Started "attente : synchro relancee"
  Assert-Equal "sync..." (Get-DriveTag $waitJob)[0] "nouvel essai en cours"
  $held = New-DriveJob $true $at
  Start-DriveJob $held -Hold
  Assert-True ((-not (Test-DriveJobRunning $held)) -and (Get-DriveTag $held)[0] -eq ("sync " + $hm)) "synchro chargee en avance : pas encore en cours"
  Assert-Equal "  synchro Drive lancee" (Request-DriveSync $held)[0] "touche y pendant le chargement : synchro lancee"
  Assert-True ((Test-DriveJobRunning $held) -and $script:Started -eq 3) "synchro chargee en avance : relachee sans nouvelle tache"
  $held = New-DriveJob $true $at
  Start-DriveJob $held -Hold
  Stop-DriveJob $held 0
  Assert-True ($held.Ctl.Stop -and $held.Loader.Ctl.Go.IsSet) "arret pendant le chargement : tache relachee pour finir"
} finally { Set-Item "function:Start-UsageLoader" $keptLoader }
$job.Loader.Ctl.Done = $true
Stop-DriveJob $job
Assert-True $job.Ctl.Stop "arret demande a la tache"
Assert-Null $job.Loader "tache terminee liberee"

Assert-Equal "drivesync" (Get-MenuAction ([ConsoleKeyInfo]::new("y", [ConsoleKey]::Y, $false, $false, $false)) 2).Name "touche y"

$script:DriveJob = New-DriveJob $true $at
$hst = @{ Version = "clm abcdef1" }
$row = Get-MenuHeaderRow $hst 80
Assert-True ((Get-JobSegsText $row) -match ("Comptes Claude Code  clm abcdef1  sync " + $hm + " +\d\d:\d\d$")) "en-tete : version puis synchro"
$seg = @($row | Where-Object { $_[0] -eq ("sync " + $hm) })[0]
Assert-Equal "y" $seg[3] "en-tete : clic sur la synchro rend y"
Assert-True ((Get-JobSegsText (Get-MenuHeaderRow $hst 52)) -match "clm abcdef1 +\d\d:\d\d$") "fenetre etroite : synchro retiree avant la version"
foreach ($w in 30, 52, 80) { Assert-True ((Get-JobSegsText (Get-MenuHeaderRow $hst $w)).Length -le $w - 2) ("en-tete avec synchro dans la largeur " + $w) }

$script:DriveJob.Away = @{ ".claude-compte2" = "MAC" }
$awayE = @{ U = [PSCustomObject]@{ Label = "c2"; Email = "a@b"; Plan = "Pro"; Acc = [PSCustomObject]@{ Label = "c2"; Dir = ".claude-compte2" } }; View = @{ Badge = ""; Note = "" } }
Assert-True ((Get-JobSegsText (Get-CardHead $awayE 1 @{ Mode = "full"; W = 80 } 1.0)[0]) -match "c2 +ouvert sur MAC  Pro$") "carte : compte ouvert sur un autre PC"
Assert-True ((Get-JobSegsText (Get-CardHead $awayE 1 @{ Mode = "compact"; W = 80 } 1.0)[0]) -match "ouvert sur MAC  Pro$") "carte compacte : compte ouvert ailleurs"
$awayE.U.Acc = [PSCustomObject]@{ Label = "c1"; Dir = ".claude" }
Assert-True ((Get-JobSegsText (Get-CardHead $awayE 0 @{ Mode = "full"; W = 80 } 1.0)[0]) -notmatch "ouvert") "carte : compte libre, rien"
Assert-True (@(foreach ($fr in (Get-FooterRows $script:MenuFooter 105)) { $fr | Where-Object { $_[3] -eq "y" } }).Count -gt 0) "pied de page : touche y"

$script:DriveJob = $keptJob
