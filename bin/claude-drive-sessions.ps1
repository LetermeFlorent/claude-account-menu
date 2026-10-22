if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
$script:DriveSessionDir = Join-Path (Get-HomeDir) ".clm-drive-watch"
$script:DriveSessionStampSlack = 2
$script:DriveLiveExt = ".json"
$script:DriveEndedExt = ".end"
$script:DriveHeldName = ".claude.json"

function Get-ProcessStamp {
  param([int]$ProcessId)
  try { $p = Get-Process -Id $ProcessId -ErrorAction Stop } catch { return [long]-1 }
  try { return [long][Math]::Floor($p.StartTime.ToUniversalTime().Ticks / [TimeSpan]::TicksPerSecond) } catch { return [long]-1 }
}

function Test-SessionAlive {
  param($Session)
  $s = Get-ProcessStamp $Session.Pid
  return $s -ge 0 -and [Math]::Abs($s - $Session.Start) -le $script:DriveSessionStampSlack
}

function New-SessionPath {
  param([int]$ProcessId)
  return Join-Path $script:DriveSessionDir ("" + $ProcessId + "-" + [guid]::NewGuid().ToString("N") + $script:DriveLiveExt)
}

function Register-DriveSession {
  param($Acc, [int]$ProcessId = $PID)
  $null = [IO.Directory]::CreateDirectory($script:DriveSessionDir)
  $path = New-SessionPath $ProcessId
  Write-TextFileAtomic $path (ConvertTo-JsonText ([ordered]@{ pid = $ProcessId; start = (Get-ProcessStamp $ProcessId); dir = [string]$Acc.Dir }))
  return $path
}

function Close-DriveSession {
  param([string]$Path)
  if (-not $Path -or -not [IO.File]::Exists($Path)) { return "" }
  $ended = [IO.Path]::ChangeExtension($Path, $script:DriveEndedExt)
  [IO.File]::Move($Path, $ended)
  return $ended
}

function Read-DriveSession {
  param([string]$Path)
  try { $d = Read-JsonFile $Path } catch { return $null }
  if ($null -eq $d) { return $null }
  return @{ Path = $Path; Pid = [int]$d["pid"]; Start = [long]$d["start"]; Dir = [string]$d["dir"]; Ended = $Path.EndsWith($script:DriveEndedExt) }
}

function Read-DriveSessions {
  $out = New-Object 'System.Collections.Generic.List[object]'
  if (-not [IO.Directory]::Exists($script:DriveSessionDir)) { return $out.ToArray() }
  foreach ($f in [IO.Directory]::GetFiles($script:DriveSessionDir)) {
    if (-not ($f.EndsWith($script:DriveLiveExt) -or $f.EndsWith($script:DriveEndedExt))) { continue }
    $s = Read-DriveSession $f
    if ($null -ne $s) { $out.Add($s) }
  }
  return $out.ToArray()
}

function Get-HeldPath {
  param([string]$Dir)
  if ($Dir -eq ".claude") { return $script:DriveHeldName }
  return $Dir + "/" + $script:DriveHeldName
}

function Get-HeldPaths {
  $held = New-Object 'System.Collections.Generic.List[string]'
  foreach ($s in @(Read-DriveSessions)) {
    if (-not $s.Ended -and $s.Dir -and (Test-SessionAlive $s)) { $held.Add((Get-HeldPath $s.Dir)) }
  }
  return $held.ToArray()
}
