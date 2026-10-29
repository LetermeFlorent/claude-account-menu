if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-drive-files, claude-drive-state, claude-drive-plan, claude-drive-transfer,
  claude-drive-prefetch, claude-drive-sealed, claude-drive-conflict, claude-drive-transfer-file, claude-text
$script:DriveFailLimit = 3
$script:DriveEchoEvery = 25
$script:DriveSaveEveryMs = 60000
$script:LocalActionKinds = @("upload", "download", "delete-local", "keep-local", "keep-remote")

function Get-SyncLocalPath {
  param([string]$Rel)
  return Get-SyncRootPath $script:HomeDir $Rel
}

function Save-SyncCheckpoint {
  param($Ctx, [bool]$Now)
  $t = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if (-not $Now -and $t - [long]$Ctx.SavedAt -lt $script:DriveSaveEveryMs) { return }
  Save-DriveState $Ctx.State
  $Ctx.SavedAt = $t
}

function Set-SyncProgress {
  param($Ctl, [int]$Done, [int]$Total)
  if ($null -eq $Ctl) { return }
  $Ctl.Progress = "" + $Done + "/" + $Total
  if ($Ctl.Echo -and ($Done % $script:DriveEchoEvery -eq 0 -or $Done -eq $Total)) { Write-Host ("  " + (Get-ClmText "drive.progress" @($Ctl.Progress))) }
}

function New-BaseEntry {
  param([string]$Path, [string]$Md5, [string]$Id)
  $info = [IO.FileInfo]$Path
  return @{ Md5 = $Md5; M = (ConvertTo-UnixSeconds $info.LastWriteTimeUtc); Size = $info.Length; Id = $Id }
}

function Send-SyncFile {
  param($Ctx, [string]$Rel)
  $L = $Ctx.Local[$Rel]
  $r = Get-PrefetchedUpload $Ctx.Prefetch $Rel
  if ($null -eq $r) { $r = Send-LocalFile $Ctx.Folder $Rel $L.Full (Get-UploadProps $Ctx $Rel) (Get-RemoteId $Ctx $Rel) $Ctx.Keys }
  $md5 = $r.Md5
  if (-not $md5) { $md5 = $L.Md5 }
  $Ctx.State.Files[$Rel] = @{ Md5 = $md5; M = $L.M; Size = $L.Size; Id = $r.Id }
}

function Test-LocalAsScanned {
  param($Ctx, [string]$Rel)
  $info = [IO.FileInfo](Get-SyncLocalPath $Rel)
  $L = $Ctx.Local[$Rel]
  if ($null -eq $L) { return -not $info.Exists }
  return $info.Exists -and $info.Length -eq [long]$L.Size -and (ConvertTo-UnixSeconds $info.LastWriteTimeUtc) -eq [long]$L.M
}

function Test-SharedFilePath {
  param([string]$Rel)
  $parts = $Rel.Split("/")
  return $parts.Count -eq 2 -and $parts[0] -eq ".claude" -and $script:SharedFiles -contains $parts[1]
}

function Receive-SyncFile {
  param($Ctx, [string]$Rel)
  $R = $Ctx.Remote[$Rel]
  $path = Get-SyncLocalPath $Rel
  $tmp = Get-PrefetchedTemp $Ctx.Prefetch $Rel
  if (-not $tmp) { $tmp = Receive-DriveTemp $R.Id $path ($script:SealedFilesArea + $Rel) $Ctx.Keys }
  try {
    if (-not (Test-LocalAsScanned $Ctx $Rel)) { return $false }
    Restore-LocalMachineSettings $tmp $path $Rel
    Install-DriveTemp $tmp $path -InPlace:(Test-SharedFilePath $Rel)
  } finally { Remove-DriveTemp $tmp }
  if ([long]$R.M -gt 0) { [IO.File]::SetLastWriteTimeUtc($path, [DateTimeOffset]::FromUnixTimeSeconds([long]$R.M).UtcDateTime) }
  $Ctx.State.Files[$Rel] = New-BaseEntry $path $R.Md5 $R.Id
  return $true
}

function Invoke-SyncAction {
  param($Ctx, $Action)
  $p = $Action.Path
  if ($script:LocalActionKinds -contains $Action.Kind -and -not (Test-SafeSyncPath $p)) { throw (Get-ClmText "drive.action.unsafePath" @($p)) }
  $res = $Ctx.Res
  switch ($Action.Kind) {
    "upload" { Send-SyncFile $Ctx $p; $res.Up++ }
    "download" { if (-not (Receive-SyncFile $Ctx $p)) { return $false }; $res.Down++ }
    "delete-local" {
      if (-not (Test-LocalAsScanned $Ctx $p)) { return $false }
      Remove-SyncLocalFile $p
      $Ctx.State.Files.Remove($p); $res.Deleted++
    }
    "delete-remote" { foreach ($id in (Get-RemoteIds $Ctx.Remote[$p])) { Remove-DriveFile $id }; $Ctx.State.Files.Remove($p); $res.Deleted++ }
    "refuse" { throw (New-SealRefusal) }
    "forget" { $Ctx.State.Files.Remove($p) }
    "adopt" {
      $L = $Ctx.Local[$p]
      $Ctx.State.Files[$p] = @{ Md5 = $L.Md5; M = $L.M; Size = $L.Size; Id = $Ctx.Remote[$p].Id }
    }
    "keep-local" { Save-RemoteConflict $Ctx $p; Send-SyncFile $Ctx $p; $res.Conflicts++ }
    "keep-remote" {
      if (-not (Test-LocalAsScanned $Ctx $p)) { return $false }
      Save-LocalConflict $Ctx $p
      if (-not (Receive-SyncFile $Ctx $p)) { return $false }
      $res.Conflicts++
    }
  }
  return $true
}

function Invoke-SyncPlan {
  param($Ctx, $Plan, $Ctl, [long]$DeadlineMs)
  $done = 0
  $fails = 0
  $later = 0
  $baseOnly = $false
  $Ctx.SavedAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $Ctx.Prefetch = Start-TransferPrefetch $Ctx $Plan $DeadlineMs
  try {
    foreach ($a in $Plan) {
      if (Test-SyncStop $Ctl $DeadlineMs) { break }
      $afterBaseOnly = $baseOnly
      $baseOnly = $script:BaseOnlyKinds -contains $a.Kind
      Save-SyncCheckpoint $Ctx ($afterBaseOnly -and -not $baseOnly)
      $done++
      try {
        if (-not (Invoke-SyncAction $Ctx $a)) { $later++ }
        $fails = 0
      } catch {
        $Ctx.Res.Failed++
        if (Test-SealRefusal $_) { $Ctx.Res.Refused.Add($a.Path) }
        else {
          if (-not $Ctx.Res.Failure) { $Ctx.Res.Failure = $a.Path + " : " + $_.Exception.Message }
          $fails++
          if ($fails -ge $script:DriveFailLimit) { $Ctx.Res.Left = $Plan.Count - $done + $later; throw }
        }
      }
      Set-SyncProgress $Ctl $done $Plan.Count
    }
  } finally { Stop-TransferPrefetch $Ctx.Prefetch; $Ctx.Prefetch = $null }
  $Ctx.Res.Left = $Plan.Count - $done + $later
}
