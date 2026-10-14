. (Join-Path $PSScriptRoot "claude-drive-files.ps1")
. (Join-Path $PSScriptRoot "claude-drive-plan.ps1")
. (Join-Path $PSScriptRoot "claude-drive-creds.ps1")
$script:DriveLockPath = Join-Path (Get-HomeDir) ".clm-drive.lock"
$script:DriveLockWaitMs = 5000
$script:DriveDeleteLimit = 20
$script:DriveFailLimit = 3
$script:DriveExitBudgetMs = 30000
$script:DriveRootPattern = '^\.(claude[^/]*|mcp\.json)$'
$script:DriveEchoEvery = 25

function Invoke-WithDriveLock {
  param([scriptblock]$Action)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($script:DriveLockWaitMs)
  while ($true) {
    try { $fs = [IO.File]::Open($script:DriveLockPath, "OpenOrCreate", "ReadWrite", "None"); break }
    catch {
      if ([DateTime]::UtcNow -ge $deadline) { throw "une autre synchro Drive est en cours" }
      Start-Sleep -Milliseconds 200
    }
  }
  try { & $Action } finally { $fs.Dispose() }
}

function New-SyncResult {
  return @{ Ok = $false; Error = ""; At = [long]0; Left = 0; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Failed = 0; Total = 0; Away = @{} }
}

function Test-SafeSyncPath {
  param([string]$Rel)
  if ($Rel -eq "" -or $Rel.Contains("\") -or $Rel.Contains(":")) { return $false }
  $parts = $Rel.Split("/")
  if ($parts[0] -notmatch $script:DriveRootPattern) { return $false }
  foreach ($s in $parts) { if ($s -eq "" -or $s -eq "." -or $s -eq "..") { return $false } }
  return $true
}

function Select-RemoteFiles {
  param($Listing, $Patterns)
  $out = New-PathMap
  foreach ($k in $Listing.Keys) {
    if ((Test-SafeSyncPath $k) -and -not (Test-SyncExcluded $k $Patterns)) { $out[$k] = $Listing[$k] }
  }
  return $out
}

function Get-SyncLocalPath {
  param([string]$Rel)
  return Join-Path $script:HomeDir ($Rel.Replace("/", [IO.Path]::DirectorySeparatorChar))
}

function Assert-DeleteLimit {
  param($Plan, [int]$BaseCount, [bool]$Force)
  $n = @($Plan | Where-Object { $_.Kind -eq "delete-local" -or $_.Kind -eq "delete-remote" }).Count
  $limit = [math]::Max($script:DriveDeleteLimit, [int][math]::Floor($BaseCount / 10))
  if ($n -gt $limit -and -not $Force) { throw ("synchro bloquee : " + $n + " suppressions prevues, verifier puis lancer clm --sync --force") }
}

function Test-SyncStop {
  param($Ctl, [long]$DeadlineMs)
  if ($null -ne $Ctl -and $Ctl.Stop) { return $true }
  return $DeadlineMs -gt 0 -and [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -ge $DeadlineMs
}

function Set-SyncProgress {
  param($Ctl, [int]$Done, [int]$Total)
  if ($null -eq $Ctl) { return }
  $Ctl.Progress = "" + $Done + "/" + $Total
  if ($Ctl.Echo -and ($Done % $script:DriveEchoEvery -eq 0 -or $Done -eq $Total)) { Write-Host ("  sync " + $Ctl.Progress) }
}

function New-BaseEntry {
  param([string]$Path, [string]$Md5, [string]$Id)
  $info = [IO.FileInfo]$Path
  return @{ Md5 = $Md5; M = (ConvertTo-UnixSeconds $info.LastWriteTimeUtc); Size = $info.Length; Id = $Id }
}

function Send-SyncFile {
  param($Ctx, [string]$Rel)
  $L = $Ctx.Local[$Rel]
  $id = ""
  if ($null -ne $Ctx.Remote[$Rel]) { $id = $Ctx.Remote[$Rel].Id }
  $r = Send-DriveFile $Ctx.Folder $Rel $L.Full @{ m = ("" + $L.M); pc = $Ctx.Pc } $id
  $md5 = $r.Md5
  if (-not $md5) { $md5 = $L.Md5 }
  $Ctx.State.Files[$Rel] = @{ Md5 = $md5; M = $L.M; Size = $L.Size; Id = $r.Id }
}

function Receive-SyncFile {
  param($Ctx, [string]$Rel)
  $R = $Ctx.Remote[$Rel]
  $path = Get-SyncLocalPath $Rel
  Receive-DriveFile $R.Id $path
  if ([long]$R.M -gt 0) { [IO.File]::SetLastWriteTimeUtc($path, [DateTimeOffset]::FromUnixTimeSeconds([long]$R.M).UtcDateTime) }
  $Ctx.State.Files[$Rel] = New-BaseEntry $path $R.Md5 $R.Id
}

function Save-RemoteConflict {
  param($Ctx, [string]$Rel)
  $R = $Ctx.Remote[$Rel]
  $pc = $R.Pc
  if (-not $pc) { $pc = "drive" }
  Receive-DriveFile $R.Id (Get-SyncLocalPath (Get-ConflictPath $Rel $pc))
}

function Save-LocalConflict {
  param($Ctx, [string]$Rel)
  [IO.File]::WriteAllBytes((Get-SyncLocalPath (Get-ConflictPath $Rel $Ctx.Pc)), (Read-SharedBytes $Ctx.Local[$Rel].Full))
}

function Invoke-SyncAction {
  param($Ctx, $Action)
  $p = $Action.Path
  $res = $Ctx.Res
  switch ($Action.Kind) {
    "upload" { Send-SyncFile $Ctx $p; $res.Up++ }
    "download" { Receive-SyncFile $Ctx $p; $res.Down++ }
    "delete-local" {
      $full = Get-SyncLocalPath $p
      if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Force -ErrorAction Stop }
      $Ctx.State.Files.Remove($p); $res.Deleted++
    }
    "delete-remote" { Remove-DriveFile $Ctx.Remote[$p].Id; $Ctx.State.Files.Remove($p); $res.Deleted++ }
    "forget" { $Ctx.State.Files.Remove($p) }
    "adopt" {
      $L = $Ctx.Local[$p]
      $Ctx.State.Files[$p] = @{ Md5 = $L.Md5; M = $L.M; Size = $L.Size; Id = $Ctx.Remote[$p].Id }
    }
    "keep-local" { Save-RemoteConflict $Ctx $p; Send-SyncFile $Ctx $p; $res.Conflicts++ }
    "keep-remote" { Save-LocalConflict $Ctx $p; Receive-SyncFile $Ctx $p; $res.Conflicts++ }
  }
}

function Invoke-SyncPlan {
  param($Ctx, $Plan, $Ctl, [long]$DeadlineMs)
  $done = 0
  $fails = 0
  foreach ($a in $Plan) {
    if (Test-SyncStop $Ctl $DeadlineMs) { break }
    $done++
    try { Invoke-SyncAction $Ctx $a; $fails = 0 }
    catch {
      $Ctx.Res.Failed++
      $fails++
      if ($fails -ge $script:DriveFailLimit) { $Ctx.Res.Left = $Plan.Count - $done; throw }
    }
    Set-SyncProgress $Ctl $done $Plan.Count
  }
  $Ctx.Res.Left = $Plan.Count - $done
}

function Set-DriveLastSync {
  param([long]$At)
  $c = Read-DriveConfig
  if ($null -eq $c) { return }
  $c["lastSync"] = $At
  Save-DriveConfig $c
}

function Invoke-DriveSyncPass {
  param($Res, $Ctl, [long]$DeadlineMs, [bool]$Force)
  $folders = Get-DriveFolders
  $pc = Get-DrivePcName
  $accs = @(Get-Accounts)
  $Res.Failed += [int](Sync-DriveCredentials $folders $accs)
  $Res.Away = Get-AwayMap (Get-DriveListing $folders.Presence) $pc ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $state = Read-DriveState
  $patterns = Get-SyncPatterns $accs
  $local = Get-LocalFiles $script:HomeDir (Get-SyncRoots $accs) $patterns $state.Files
  $remote = Select-RemoteFiles (Get-DriveListing $folders.Files) $patterns
  $plan = Get-SyncPlan $local.Files $state.Files $remote $local.Skipped -Joining:($state.At -eq 0)
  Assert-DeleteLimit $plan $state.Files.Count $Force
  $Res.Total = $plan.Count
  $ctx = @{ Folder = $folders.Files; Pc = $pc; State = $state; Local = $local.Files; Remote = $remote; Res = $Res }
  try { Invoke-SyncPlan $ctx $plan $Ctl $DeadlineMs }
  finally {
    if ($Res.Left -eq 0 -and $Res.Failed -eq 0) { $state.At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    Save-DriveState $state
  }
  if ($Res.Failed -gt 0) { $Res.Error = "" + $Res.Failed + " fichier(s) en echec, nouvel essai a la prochaine synchro"; return }
  $Res.Ok = $true
  if ($Res.Left -eq 0) { $Res.At = $state.At; Set-DriveLastSync $state.At }
}

function Invoke-DriveSync {
  param($Ctl = $null, [long]$DeadlineMs = 0, [switch]$Force)
  $res = New-SyncResult
  try { Invoke-WithDriveLock { Invoke-DriveSyncPass $res $Ctl $DeadlineMs $Force.IsPresent } }
  catch { $res.Ok = $false; $res.Error = $_.Exception.Message }
  return $res
}

function Get-DriveSyncMsg {
  param($Result)
  if ($Result.Error) { return "synchro Drive : " + $Result.Error }
  $t = "synchro Drive : " + $Result.Up + " envoyes, " + $Result.Down + " recus, " + $Result.Deleted + " supprimes, " + $Result.Conflicts + " conflits"
  if ($Result.Left -gt 0) { $t += ", " + $Result.Left + " restants pour la prochaine synchro" }
  return $t
}

function Sync-DriveBeforeLaunch {
  param($Acc)
  if (-not (Test-DriveConnected)) { return }
  try {
    $null = Sync-OneCredential $Acc
    Set-DrivePresence $Acc $true
  } catch { Write-Host ("  Drive : " + $_.Exception.Message) -ForegroundColor DarkYellow }
}

function Sync-DriveAfterExit {
  param($Acc)
  if (-not (Test-DriveConnected)) { return }
  try { Set-DrivePresence $Acc $false } catch {}
  if (-not (Test-DriveAuto)) { return }
  $r = Invoke-DriveSync $null ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:DriveExitBudgetMs)
  if ($r.Error -or $r.Left -gt 0) { Write-Host ("  " + (Get-DriveSyncMsg $r)) -ForegroundColor DarkYellow }
}
