. (Join-Path $PSScriptRoot "claude-drive-actions.ps1")
. (Join-Path $PSScriptRoot "claude-drive-creds.ps1")
$script:DriveLockPath = Join-Path (Get-HomeDir) ".clm-drive.lock"
$script:DriveLockWaitMs = 5000
$script:DriveDeleteLimit = 20
$script:DriveExitBudgetMs = 30000
$script:DriveRootPattern = '^\.(claude[^/]*|mcp\.json)$'

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

function Assert-DeleteLimit {
  param($Plan, [int]$BaseCount, [bool]$Force)
  $n = @($Plan | Where-Object { $_.Kind -eq "delete-local" -or $_.Kind -eq "delete-remote" }).Count
  $limit = [math]::Max($script:DriveDeleteLimit, [int][math]::Floor($BaseCount / 10))
  if ($n -gt $limit -and -not $Force) { throw ("synchro bloquee : " + $n + " suppressions prevues, verifier puis lancer clm --sync --force") }
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
  param($Acc, [long]$DeadlineMs)
  if (-not (Test-DriveConnected)) { return }
  try { Set-DrivePresence $Acc $false } catch {}
  if (-not (Test-DriveAuto)) { Send-DriveCredential $Acc; return }
  Write-Host "  synchro Drive..." -ForegroundColor DarkGray
  $r = Invoke-DriveSync $null $DeadlineMs
  if ($r.Error -or $r.Left -gt 0) { Write-Host ("  " + (Get-DriveSyncMsg $r)) -ForegroundColor DarkYellow }
}
