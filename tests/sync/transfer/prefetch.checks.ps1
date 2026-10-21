. (Join-Path (Split-Path -Parent $PSScriptRoot) "fake-drive.ps1")
$prefetchSaved = @($script:DrivePrefetchSource, $script:DrivePrefetchMin, $script:DrivePrefetchStopMs)
$script:DrivePrefetchSource = Join-Path $PSScriptRoot "fake-worker.ps1"
$script:DrivePrefetchMin = 1
$script:DriveParallel = 3
Use-Pc "PCP"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })

function Add-FakeRemote {
  param([string]$Name, [string]$Id, [string]$Text)
  $b = [Text.Encoding]::UTF8.GetBytes($Text)
  $script:Fake[$Name] = @{ Id = $Id; Name = $Name; Md5 = (Get-FakeMd5 $b); M = 1700000000; Pc = "PCB"; Exp = 0; Props = @{ m = "1700000000"; pc = "PCB" }; Bytes = $b }
}

function Get-TempCount {
  return @(Get-ChildItem -LiteralPath $script:HomeDir -Recurse -Filter "*.tmp" -File).Count
}

foreach ($i in 1..4) { Add-FakeRemote (".claude/recu/" + $i + ".md") ("r" + $i) ("drive-" + $i) }
Add-FakeRemote ".claude/recu/casse.md" "panne1" "drive-casse"
Set-PcFile ".claude/envoi/a.md" "aaa"
Set-PcFile ".claude/envoi/b.md" "bbbb"
$seqBefore = $script:FakeSeq
$r = Invoke-DriveSync
Assert-True $r.Ok ("parallele : synchro reussie " + $r.Error)
Assert-Equal "5|3|0" ("" + $r.Down + "|" + $r.Up + "|" + $r.Failed) "parallele : tout recu, tout envoye"
Assert-Equal "pre-r3" (Get-PcText ".claude/recu/3.md") "parallele : fichier recu en avance puis installe"
Assert-Equal "drive-casse" (Get-PcText ".claude/recu/casse.md") "parallele : echec en avance, nouvel essai en ligne"
Assert-Equal "up-.claude/envoi/b.md-4-PCP" (Read-DriveState).Files[".claude/envoi/b.md"].Id "parallele : envoi fait en avance garde dans la base"
Assert-Equal $seqBefore $script:FakeSeq "parallele : pas de second envoi"
Assert-Equal "bbbb" (Get-PcText ".claude/envoi/b.md") "parallele : fichier envoye intact"
Assert-Equal 0 (Get-TempCount) "parallele : aucun fichier temporaire laisse"

$ctx = @{ Folder = "F"; Pc = "PCP"; Local = (New-PathMap); Remote = (New-PathMap) }
$ctx.Remote[".claude/x/1.md"] = @{ Id = "x1" }
$ctx.Remote[".claude/x/2.md"] = @{ Id = "x2" }
$ctx.Local[".claude/x/gros.bin"] = @{ Size = $script:DriveSimpleMax + 1; M = 1; Full = "absent" }
$ctx.Local[".claude/x/petit.md"] = @{ Size = 3; M = 7; Full = (New-SandboxFile "petit.md" "abc") }
$plan = @(@{ Kind = "download"; Path = ".claude/x/1.md" }, @{ Kind = "forget"; Path = ".claude/x/z.md" }, @{ Kind = "upload"; Path = ".claude/x/gros.bin" }, @{ Kind = "upload"; Path = ".claude/x/petit.md" }, @{ Kind = "download"; Path = ".claude/x/2.md" })
$pre = Start-TransferPrefetch $ctx $plan 0
Assert-Equal "3|False" ("" + $pre.Planned.Count + "|" + $pre.Planned.ContainsKey(".claude/x/gros.bin")) "en avance : petits transferts seulement"
Assert-Equal "up-.claude/x/petit.md-3-PCP" (Get-PrefetchedUpload $pre ".claude/x/petit.md").Id "en avance : envoi fait"
Assert-Null (Get-PrefetchedUpload $pre ".claude/x/gros.bin") "en avance : gros envoi laisse en ligne"
$tmp1 = Get-PrefetchedTemp $pre ".claude/x/1.md"
Assert-Equal "pre-x1" ([IO.File]::ReadAllText($tmp1)) "en avance : fichier pret"
Assert-Equal "" (Get-PrefetchedTemp $pre ".claude/x/z.md") "en avance : action hors transferts"
$tmp2 = $pre.Planned[".claude/x/2.md"].Tmp
Stop-TransferPrefetch $pre
Assert-True (-not [IO.File]::Exists($tmp1) -and -not [IO.File]::Exists($tmp2)) "arret : temporaires non consommes retires"

$pre = Start-TransferPrefetch $ctx $plan 1
Assert-Equal "" (Get-PrefetchedTemp $pre ".claude/x/1.md") "echeance passee : rien en avance"
Stop-TransferPrefetch $pre

$ctx.Remote[".claude/x/1.md"] = @{ Id = "lent1" }
$script:DrivePrefetchStopMs = 0
$pre = Start-TransferPrefetch $ctx $plan 0
Start-Sleep -Milliseconds 300
$sw = [Diagnostics.Stopwatch]::StartNew()
Stop-TransferPrefetch $pre
Assert-True ($sw.ElapsedMilliseconds -lt 5000) "arret : transfert lent coupe"
Assert-Equal 0 (Get-TempCount) "arret : transfert lent sans temporaire"

$script:DrivePrefetchMin = 4
Assert-Null (Start-TransferPrefetch $ctx $plan 0) "peu de transferts : pas de parallele"
$script:DrivePrefetchMin = 1
$script:DriveParallel = 1
Assert-Null (Start-TransferPrefetch $ctx $plan 0) "un transfert a la fois : pas de parallele"

$ps = [PowerShell]::Create()
[void]$ps.AddScript($script:PrefetchWorkerScript).AddArgument($prefetchSaved[0]).AddArgument((New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]')).AddArgument(@{}).AddArgument(@{ Stop = $false; Deadline = 0 })
$null = $ps.Invoke()
Assert-Equal 0 $ps.Streams.Error.Count "vrai code charge dans un fil"
$ps.Dispose()

$script:DrivePrefetchSource, $script:DrivePrefetchMin, $script:DrivePrefetchStopMs = $prefetchSaved
Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
