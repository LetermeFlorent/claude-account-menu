. Import-ClmModule claude-ui-loader, claude-drive-prefetch, claude-drive-sync
$lateDir = Join-Path $script:Sandbox "late-bin"
$null = New-Item -ItemType Directory -Path $lateDir -Force
Copy-Item -LiteralPath (Join-Path $bin "claude-import.ps1") -Destination $lateDir
$lateEntry = New-SandboxFile "late-bin/late-entry.ps1" @'
if ([IO.File]::Exists((Join-Path $PSScriptRoot "bump"))) { [IO.File]::WriteAllText((Join-Path $PSScriptRoot "clm.version"), [guid]::NewGuid().ToString()) }
function Get-LateUsage { param($Account) return "charge" }
function Invoke-DriveSync { param($Ctl = $null, [long]$DeadlineMs = 0, [switch]$Force) return @{ Ok = $true; Up = 1; Error = "" } }
function Get-SyncBytes { param([string]$Rel, [string]$Full) return "octets" }
function Send-SealedFile { param($Folder, $Rel, $Bytes, $Props, $Id, $Keys) return "envoye" }
'@
$lateSyncSource = $script:FreshSyncSource
$script:FreshSyncSource = $lateEntry

function Invoke-LateUsage {
  $loader = Start-UsageLoader @("compte") $lateEntry "Get-LateUsage"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while (-not $loader.Ctl.Done -and $sw.ElapsedMilliseconds -lt 10000) { Start-Sleep -Milliseconds 10 }
  $items = Receive-UsageResults $loader
  $out = @{ Replaced = $loader.Ctl.Replaced -eq $true; Error = "" + $loader.Ctl.Error; Shown = $loader.Ps.Streams.Error.Count; Items = $items.Count }
  Close-UsageLoader $loader
  return $out
}

function Invoke-LatePrefetch {
  $work = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  $work.Enqueue(@{ Kind = "upload"; Rel = "a.txt"; Full = "a.txt"; Folder = "f"; Props = @{}; Id = "" })
  $results = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([StringComparer]::Ordinal)
  $ps = [PowerShell]::Create()
  try {
    [void]$ps.AddScript($script:PrefetchWorkerScript).AddArgument($lateEntry).AddArgument($work).AddArgument($results).AddArgument([hashtable]::Synchronized(@{ Stop = $false; Deadline = 0; Keys = $null }))
    $null = $ps.Invoke()
    return "resultats=" + $results.Count + " restants=" + $work.Count + " erreurs=" + $ps.Streams.Error.Count
  } finally { $ps.Dispose() }
}

try {
  $null = New-SandboxFile "late-bin/clm.version" "v1`n"
  $u = Invoke-LateUsage
  Assert-Equal "False||0|1" (($u.Replaced, $u.Error, $u.Shown, $u.Items) -join "|") "chargement tardif : version stable, compte lu"
  Assert-Equal "resultats=1 restants=0 erreurs=0" (Invoke-LatePrefetch) "transfert en avance : version stable, fichier envoye"
  Assert-Equal 1 (Invoke-FreshDriveSync $null 0 $false).Up "synchro fraiche : version stable, synchro faite"

  foreach ($case in @("installing", "bump")) {
    $name = "installation en cours"
    if ($case -eq "bump") { $name = "version changee pendant le chargement" }
    $flag = New-SandboxFile ("late-bin/" + @{ installing = "clm.installing"; bump = "bump" }[$case]) "1"
    $u = Invoke-LateUsage
    Assert-Equal "True||0|0" (($u.Replaced, $u.Error, $u.Shown, $u.Items) -join "|") ("chargement tardif, " + $name + " : arret discret, rien lu")
    Assert-Equal "resultats=0 restants=1 erreurs=0" (Invoke-LatePrefetch) ("transfert en avance, " + $name + " : arret discret, rien envoye")
    $r = Invoke-FreshDriveSync $null 0 $false
    Assert-Equal ("False|" + $script:DriveBusyText + "|True|0") (($r.Ok, $r.Error, $r.Busy, $r.Up) -join "|") ("synchro fraiche, " + $name + " : reportee sans erreur")
    Remove-Item -LiteralPath $flag -Force
  }
} finally { $script:FreshSyncSource = $lateSyncSource }
