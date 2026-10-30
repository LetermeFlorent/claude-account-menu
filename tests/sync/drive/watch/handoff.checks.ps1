$handoffFaked = @("Start-DriveWatcher", "Test-DriveWatcherRunning", "Sync-DriveAfterExit", "Stop-DriveJob")
$handoffKept = @{}
foreach ($n in $handoffFaked) { $handoffKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$handoffSaved = @($script:DriveConfigPath, $script:DriveSessionDir, $script:DriveWatchSpawnWaitMs)
$script:DriveConfigPath = Join-Path $script:Sandbox "handoff-drive.json"
$script:DriveSessionDir = Join-Path $script:Sandbox "handoff-watch"
$script:DriveWatchSpawnWaitMs = 200
$script:HandoffCalls = New-Object 'System.Collections.Generic.List[string]'
$script:HandoffRunning = $false
$script:HandoffStart = $true
$script:HandoffTakes = $false

function Start-DriveWatcher {
  $script:HandoffCalls.Add("veilleur")
  if ($script:HandoffTakes) { Get-ChildItem -LiteralPath $script:DriveSessionDir -Filter "*.end" | Remove-Item }
  return $script:HandoffStart
}
function Test-DriveWatcherRunning { return $script:HandoffRunning }
function Sync-DriveAfterExit { param($Acc, [long]$DeadlineMs) $script:HandoffCalls.Add("synchro dans la fenetre") }
function Stop-DriveJob { param($Job, [int]$TimeoutMs) $script:HandoffCalls.Add("arret " + $TimeoutMs) }

function Get-HandoffCalls {
  $t = $script:HandoffCalls -join ","
  $script:HandoffCalls.Clear()
  return $t
}

function Get-HandoffFiles {
  param([string]$Filter)
  return @(Get-ChildItem -LiteralPath $script:DriveSessionDir -Filter $Filter).Count
}

$acc = [PSCustomObject]@{ Label = "c"; Dir = ".claude" }
Assert-Equal "" (Open-DriveSession $acc) "Drive non connecte : aucune session"
Assert-Equal "" (Get-HandoffCalls) "Drive non connecte : pas de veilleur"
Stop-DriveSession $acc ""
Assert-Equal "arret 30000,synchro dans la fenetre" (Get-HandoffCalls) "sans session : synchro dans la fenetre comme avant"

Save-DriveConfig @{ refreshToken = "r" }
$session = Open-DriveSession $acc
Assert-True ([IO.File]::Exists($session)) "Drive connecte : session inscrite"
Assert-Equal "veilleur" (Get-HandoffCalls) "veilleur lance a l'ouverture de Claude"
$script:HandoffRunning = $true
$global:LASTEXITCODE = 3
Stop-DriveSession $acc $session
Assert-Equal 3 $global:LASTEXITCODE "code de sortie de Claude garde"
Assert-Equal "arret 2000" (Get-HandoffCalls) "sortie : main rendue, synchro laissee au veilleur"
Assert-Equal 1 (Get-HandoffFiles "*.end") "sortie : session marquee finie pour le veilleur"
Assert-Equal 0 (Get-HandoffFiles "*.json") "sortie : plus de session ouverte"
Remove-Item -LiteralPath $script:DriveSessionDir -Recurse -Force

$session = Open-DriveSession $acc
$script:HandoffRunning = $false
$script:HandoffTakes = $true
$null = Get-HandoffCalls
Stop-DriveSession $acc $session
Assert-Equal "veilleur,arret 2000" (Get-HandoffCalls) "veilleur relance et deja passe : main rendue"
$script:HandoffTakes = $false

$session = Open-DriveSession $acc
$script:HandoffStart = $false
$null = Get-HandoffCalls
Stop-DriveSession $acc $session
Assert-Equal "veilleur,arret 30000,synchro dans la fenetre" (Get-HandoffCalls) "veilleur impossible : synchro dans la fenetre"
Assert-Equal 0 (Get-HandoffFiles "*.*") "veilleur impossible : session retiree"

$script:HandoffStart = $true
$session = Open-DriveSession $acc
$null = Get-HandoffCalls
Stop-DriveSession $acc $session
Assert-Equal "veilleur,arret 30000,synchro dans la fenetre" (Get-HandoffCalls) "veilleur lance mais muet : synchro dans la fenetre"
Assert-Equal 0 (Get-HandoffFiles "*.*") "veilleur muet : session retiree"

Remove-Item -LiteralPath $script:DriveSessionDir -Recurse -Force
Remove-Item -LiteralPath $script:DriveConfigPath -Force
foreach ($n in $handoffFaked) { Set-Item ("function:" + $n) $handoffKept[$n] }
$script:DriveConfigPath, $script:DriveSessionDir, $script:DriveWatchSpawnWaitMs = $handoffSaved
