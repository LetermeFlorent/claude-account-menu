. Import-ClmModule claude-platform, claude-text
$script:ClmScriptPattern = '(^|[\\/\s"''])(claude-menu|claude-drive-watcher|claude-statusline-seed)\.ps1'
$script:ClmHostPattern = '^(pwsh|pwsh-preview|powershell)(\.exe)?$'
$script:PeerHostFilter = "Name='powershell.exe' or Name='pwsh.exe'"

function Select-ClmPeers {
  param($Rows, [int]$Self)
  $ids = @()
  foreach ($r in @($Rows)) {
    if ([int]$r.Id -eq $Self -or ([IO.Path]::GetFileName([string]$r.Exe)) -notmatch $script:ClmHostPattern) { continue }
    if ([string]$r.Line -match $script:ClmScriptPattern) { $ids += [int]$r.Id }
  }
  return $ids
}

function Get-ProcessRows {
  if ($script:OsName -eq "Windows") {
    return @(Get-CimInstance Win32_Process -Filter $script:PeerHostFilter -ErrorAction Stop | ForEach-Object { [PSCustomObject]@{ Id = $_.ProcessId; Exe = $_.Name; Line = $_.CommandLine } })
  }
  $ps = (Get-Command ps -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
  $res = Invoke-Captured $ps "-A -o pid= -o args="
  if ($null -eq $res -or $res.Code -ne 0) { throw (Get-ClmText "sync.peers.listUnreadable") }
  $rows = @()
  foreach ($l in ($res.Out -split "`n")) {
    if ($l -match '^\s*(\d+)\s+(\S+)(.*)$') { $rows += [PSCustomObject]@{ Id = $Matches[1]; Exe = $Matches[2]; Line = $Matches[2] + $Matches[3] } }
  }
  return $rows
}

function Get-ClmPeers {
  try { return @(Select-ClmPeers (Get-ProcessRows) $PID) } catch { return @(-1) }
}
