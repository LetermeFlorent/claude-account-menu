$freshSource = $script:FreshSyncSource
$freshSha = $script:ClmLoadedSha
Assert-True (-not (Test-ClmReplaced)) "clm pas mis a jour : code charge a jour"

$script:FreshSyncSource = New-SandboxFile "fresh/sync.ps1" 'function Invoke-DriveSync { param($Ctl, [long]$DeadlineMs, [switch]$Force) return @{ Ok = $true; Up = 7; Force = $Force.IsPresent; Deadline = $DeadlineMs; Ctl = $Ctl.Name } }'
$script:ClmLoadedSha = "ancienne"
Assert-True (Test-ClmReplaced) "clm mis a jour pendant que ce processus tourne"
$r = Invoke-DriveSync @{ Name = "ctl" } 42 -Force
Assert-Equal "True 7 True 42 ctl" ("" + $r.Ok + " " + $r.Up + " " + $r.Force + " " + $r.Deadline + " " + $r.Ctl) "clm mis a jour : synchro faite par le code installe"

$script:FreshSyncSource = New-SandboxFile "fresh/casse.ps1" 'throw "code casse"'
$r = Invoke-DriveSync
Assert-True (-not $r.Ok) "code installe casse : synchro en echec"
Assert-Equal ($script:FreshSyncFailed + " : code casse") $r.Error "code installe casse : raison donnee"

$script:FreshSyncSource = New-SandboxFile "fresh/vide.ps1" 'function Invoke-DriveSync { }'
$r = Invoke-DriveSync
Assert-Equal $script:FreshSyncFailed $r.Error "code installe sans resultat : echec dit"

$script:ClmLoadedSha = $freshSha
$script:FreshSyncSource = $freshSource
Remove-Item -LiteralPath (Join-Path $script:Sandbox "fresh") -Recurse -Force
