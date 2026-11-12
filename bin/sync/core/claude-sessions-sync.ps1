. Import-ClmModule claude-json, claude-state, claude-file-io
$script:SessionSyncPath = Get-StatePath "sessions-sync.json"
$script:SessionSyncDir = "projects"
$script:SessionTmpExt = ".clm-tmp"

function Test-SessionSyncOn {
  try { $d = Read-JsonFile $script:SessionSyncPath } catch { return $false }
  return $d -is [Collections.IDictionary] -and $d["on"] -eq $true
}

function Set-SessionSync {
  param([bool]$On)
  Write-TextFileAtomic $script:SessionSyncPath ((ConvertTo-JsonText ([ordered]@{ on = $On })) + "`n")
}

function Read-SessionBytes {
  param([string]$Path)
  $fs = [IO.File]::Open($Path, "Open", "Read", "ReadWrite, Delete")
  try {
    $data = New-Object byte[] $fs.Length
    $n = 0
    while ($n -lt $data.Length) { $r = $fs.Read($data, $n, $data.Length - $n); if ($r -le 0) { break }; $n += $r }
    if ($n -lt $data.Length) { [Array]::Resize([ref]$data, $n) }
    return ,$data
  } finally { $fs.Dispose() }
}

function Test-BytesPrefix {
  param([byte[]]$Short, [byte[]]$Long)
  if ($Short.Length -gt $Long.Length) { return $false }
  $head = New-Object byte[] $Short.Length
  [Array]::Copy($Long, $head, $Short.Length)
  return [Linq.Enumerable]::SequenceEqual($Short, $head)
}

function Copy-SessionFile {
  param([string]$Src, [string]$Dst, [long]$Len)
  $have = [IO.File]::Exists($Dst)
  if ($have -and (New-Object IO.FileInfo $Dst).Length -ge $Len) { return $false }
  $data = Read-SessionBytes $Src
  if ($have -and -not (Test-BytesPrefix (Read-SessionBytes $Dst) $data)) { return $false }
  $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Dst))
  $tmp = $Dst + $script:SessionTmpExt
  [IO.File]::WriteAllBytes($tmp, $data)
  if ($have) { [IO.File]::Replace($tmp, $Dst, $null) } else { [IO.File]::Move($tmp, $Dst) }
  return $true
}

function Get-SessionFiles {
  param([string[]]$Roots)
  $best = @{}
  foreach ($r in $Roots) {
    if (-not [IO.Directory]::Exists($r)) { continue }
    foreach ($f in [IO.Directory]::EnumerateFiles($r, "*", "AllDirectories")) {
      if ($f.EndsWith($script:SessionTmpExt)) { continue }
      $rel = $f.Substring($r.Length)
      $len = (New-Object IO.FileInfo $f).Length
      if (-not $best.ContainsKey($rel) -or $len -gt $best[$rel].Len) { $best[$rel] = @{ Path = $f; Len = $len } }
    }
  }
  return $best
}

function Sync-AccountSessions {
  param($Accounts)
  $roots = [string[]]@($Accounts | ForEach-Object { Join-Path (Get-AccountPath $_) $script:SessionSyncDir } | Select-Object -Unique)
  $best = Get-SessionFiles $roots
  $copied = 0
  foreach ($rel in $best.Keys) {
    foreach ($r in $roots) {
      $dst = $r + $rel
      if ($dst -eq $best[$rel].Path) { continue }
      try { if (Copy-SessionFile $best[$rel].Path $dst $best[$rel].Len) { $copied++ } } catch { Write-Verbose $_.Exception.Message }
    }
  }
  return $copied
}
