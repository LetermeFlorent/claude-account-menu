. (Join-Path $PSScriptRoot "claude-drive-files.ps1")
. (Join-Path $PSScriptRoot "claude-drive-plan.ps1")
. (Join-Path $PSScriptRoot "claude-drive-transfer.ps1")
$script:DriveFailLimit = 3
$script:DriveEchoEvery = 25

function Get-SyncLocalPath {
  param([string]$Rel)
  return Join-Path $script:HomeDir ($Rel.Replace("/", [IO.Path]::DirectorySeparatorChar))
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
  $tmp = Receive-DriveTemp $R.Id $path
  try {
    if (-not (Test-LocalAsScanned $Ctx $Rel)) { return $false }
    Install-DriveTemp $tmp $path -InPlace:(Test-SharedFilePath $Rel)
  } finally { Remove-DriveTemp $tmp }
  if ([long]$R.M -gt 0) { [IO.File]::SetLastWriteTimeUtc($path, [DateTimeOffset]::FromUnixTimeSeconds([long]$R.M).UtcDateTime) }
  $Ctx.State.Files[$Rel] = New-BaseEntry $path $R.Md5 $R.Id
  return $true
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
    "download" { if (-not (Receive-SyncFile $Ctx $p)) { return $false }; $res.Down++ }
    "delete-local" {
      if (-not (Test-LocalAsScanned $Ctx $p)) { return $false }
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
  foreach ($a in $Plan) {
    if (Test-SyncStop $Ctl $DeadlineMs) { break }
    $done++
    try {
      if (-not (Invoke-SyncAction $Ctx $a)) { $later++ }
      $fails = 0
    } catch {
      $Ctx.Res.Failed++
      $fails++
      if ($fails -ge $script:DriveFailLimit) { $Ctx.Res.Left = $Plan.Count - $done + $later; throw }
    }
    Set-SyncProgress $Ctl $done $Plan.Count
  }
  $Ctx.Res.Left = $Plan.Count - $done + $later
}
