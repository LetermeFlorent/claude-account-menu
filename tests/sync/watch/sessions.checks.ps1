. (Join-Path (Split-Path -Parent $PSScriptRoot) "fake-drive.ps1")
Use-Pc "PCS"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "compte2"; Dir = ".claude-compte2" })

function Get-SortedHeld {
  $h = [string[]]@(Get-HeldPaths)
  [Array]::Sort($h, [StringComparer]::Ordinal)
  return $h -join "|"
}

Assert-Equal 0 @(Read-DriveSessions).Count "aucune session au depart"
Assert-Equal "" (Get-SortedHeld) "aucun fichier tenu sans session"
$first = Register-DriveSession @{ Dir = ".claude-compte2" }
Assert-True ([IO.File]::Exists($first)) "session inscrite"
$read = @(Read-DriveSessions)
Assert-Equal 1 $read.Count "une session lue"
Assert-Equal $PID $read[0].Pid "numero du processus garde"
Assert-True (-not $read[0].Ended) "session ouverte"
Assert-True (Test-SessionAlive $read[0]) "processus vivant reconnu"
Assert-Equal ".claude-compte2/.claude.json" (Get-SortedHeld) "config du compte ouvert tenue"
$second = Register-DriveSession @{ Dir = ".claude" }
Assert-True ($first -ne $second) "deux sessions du meme processus : deux fichiers"
Assert-Equal ".claude-compte2/.claude.json|.claude.json" (Get-SortedHeld) "compte principal : config a la racine"

$ended = Close-DriveSession $second
Assert-True $ended.EndsWith(".end") "session fermee marquee finie"
Assert-True (-not [IO.File]::Exists($second)) "fichier de session ouverte retire"
Assert-Equal ".claude-compte2/.claude.json" (Get-SortedHeld) "session finie : config liberee"
Assert-Equal "" (Close-DriveSession $second) "fermer deux fois : rien"
Assert-Equal "" (Close-DriveSession "") "fermer sans session : rien"
Assert-True (@(Read-DriveSessions | Where-Object { $_.Ended }).Count -eq 1) "session finie relue"

Assert-True (-not (Test-SessionAlive @{ Pid = $PID; Start = 1 })) "numero reutilise par un autre processus : session morte"
Assert-True (-not (Test-SessionAlive @{ Pid = 999999; Start = 1 })) "processus disparu : session morte"
$null = New-Item -ItemType Directory -Path $script:DriveSessionDir -Force
[IO.File]::WriteAllText((Join-Path $script:DriveSessionDir "abime.json"), "{pas du json")
[IO.File]::WriteAllText((Join-Path $script:DriveSessionDir "watch.log"), "journal")
Assert-Equal 2 @(Read-DriveSessions).Count "fichier abime et journal ignores"

Set-PcFile ".claude.json" '{"theme":"dark"}' 1700000000
Set-PcFile ".claude-compte2/.claude.json" '{"theme":"light"}' 1700000000
Set-PcFile ".claude/settings.json" "s" 1700000000
$r = Invoke-DriveSync
Assert-True $r.Ok ("synchro avec un compte ouvert " + $r.Error)
Assert-True (Test-FakeFile ".claude.json") "compte ferme : config envoyee"
Assert-True (-not (Test-FakeFile ".claude-compte2/.claude.json")) "compte ouvert : config gardee pour la sortie"
$null = Close-DriveSession $first
$r = Invoke-DriveSync
Assert-True $r.Ok ("synchro apres la sortie " + $r.Error)
Assert-True (Test-FakeFile ".claude-compte2/.claude.json") "sortie : config du compte envoyee"

Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
