. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")

Use-Pc "CP"
Save-Registry @([PSCustomObject]@{ Label = "c1"; Dir = ".claude" })
Set-PcFile ".claude/a.md" "x" 1700000000
Set-PcFile ".claude/b.md" "y" 1700000000

$script:FailSend = @(".claude/a.md")
$r = Invoke-DriveSync
Assert-Equal 1 $r.Failed "echec d'un fichier : compte"
Assert-Equal ".claude/a.md : panne reseau" $r.Failure "echec d'un fichier : chemin et raison gardes"
Assert-Equal (Get-ClmText "drive.sync.failedFiles" @(1, " (.claude/a.md : panne reseau)")) $r.Error "echec d'un fichier : raison dans le message"
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

$timingLog = Join-Path $script:DriveSessionDir $script:DriveWatchLogName
if ([IO.File]::Exists($timingLog)) { [IO.File]::Delete($timingLog) }
$saveRegistryMd5 = ${function:Get-RegistryMd5}
$script:TimingMd5 = 0
function Get-RegistryMd5 { param($Files) $script:TimingMd5++; return "" + $script:TimingMd5 }
$r = Invoke-DriveSync
${function:Get-RegistryMd5} = $saveRegistryMd5
$timing = ""
if ([IO.File]::Exists($timingLog)) { $timing = [IO.File]::ReadAllText($timingLog) }
foreach ($pass in 1, 2) {
  foreach ($step in "dossiers", "identifiants", "presence", "preferences", "base", "scan", "liste Drive", "preferences fin", "plan", "transferts", "sauvegarde", "nettoyage") {
    Assert-True ($timing -match ("synchro passe " + $pass + " " + $step + " \d+ ms")) ("duree d'etape dans le journal : passe " + $pass + " " + $step)
  }
}
Assert-True ($timing -match "synchro total \d+ ms, 2 passes") ("duree totale dans le journal " + $timing)

Restore-FakeDrive
