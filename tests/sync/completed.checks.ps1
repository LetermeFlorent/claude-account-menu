. (Join-Path $PSScriptRoot "fake-drive.ps1")

Use-Pc "CP"
Save-Registry @([PSCustomObject]@{ Label = "c1"; Dir = ".claude" })
Set-PcFile ".claude/a.md" "x" 1700000000
Set-PcFile ".claude/b.md" "y" 1700000000

$script:FailSend = @(".claude/a.md")
$r = Invoke-DriveSync
Assert-Equal 1 $r.Failed "echec d'un fichier : compte"
Assert-Equal ".claude/a.md : panne reseau" $r.Failure "echec d'un fichier : chemin et raison gardes"
Assert-Equal "1 fichier(s) en echec (.claude/a.md : panne reseau), nouvel essai a la prochaine synchro" $r.Error "echec d'un fichier : raison dans le message"
Assert-Equal 0 (Read-DriveState).At "echec d'un fichier : synchro pas complete"
$script:FailSend = @()

$saveCheckpoint = ${function:Save-SyncCheckpoint}
function Save-SyncCheckpoint { param($Ctx, [bool]$Now) throw "panne d'ecriture" }
Remove-Item -LiteralPath $script:DriveStatePath -Force
$r = Invoke-DriveSync
Assert-True (-not $r.Ok) "panne avant le premier fichier : synchro en echec"
Assert-Equal "panne d'ecriture" $r.Error "panne avant le premier fichier : raison rendue"
Assert-Equal 0 (Read-DriveState).At "panne avant le premier fichier : synchro pas marquee complete"
${function:Save-SyncCheckpoint} = $saveCheckpoint

$r = Invoke-DriveSync
Assert-True $r.Ok ("reprise : synchro complete " + $r.Error)
Assert-True ((Read-DriveState).At -gt 0) "reprise : synchro marquee complete"

Restore-FakeDrive
