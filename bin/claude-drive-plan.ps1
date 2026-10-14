function Get-PathAction {
  param($L, $B, $R, [switch]$Joining)
  if ($null -eq $L -and $null -eq $R) {
    if ($null -ne $B) { return "forget" }
    return $null
  }
  $localChanged = $null -ne $L -and ($null -eq $B -or $L.Md5 -ne $B.Md5)
  $remoteChanged = $null -ne $R -and ($null -eq $B -or $R.Md5 -ne $B.Md5)
  if ($null -eq $R) {
    if ($null -ne $B -and -not $localChanged) { return "delete-local" }
    return "upload"
  }
  if ($null -eq $L) {
    if ($null -ne $B -and -not $remoteChanged) { return "delete-remote" }
    return "download"
  }
  if ($L.Md5 -eq $R.Md5) {
    if ($null -eq $B -or $B.Md5 -ne $L.Md5 -or $B.Id -ne $R.Id) { return "adopt" }
    return $null
  }
  if (-not $localChanged) { return "download" }
  if (-not $remoteChanged) { return "upload" }
  if ($Joining -and $null -eq $B) { return "keep-remote" }
  if ([long]$L.M -ge [long]$R.M) { return "keep-local" }
  return "keep-remote"
}

function Test-UnderSkipped {
  param([string]$Path, $Skipped)
  foreach ($s in $Skipped) { if ($Path -eq $s -or $Path.StartsWith($s + "/", [StringComparison]::Ordinal)) { return $true } }
  return $false
}

function Get-SyncPlan {
  param($Local, $Base, $Remote, $Skipped = @(), [switch]$Joining, [switch]$CaseFold)
  $paths = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::Ordinal)
  foreach ($m in @($Local, $Base, $Remote)) { foreach ($k in $m.Keys) { [void]$paths.Add($k) } }
  if ($CaseFold) { $Skipped = @($Skipped) + @(Get-CaseCollisions $paths) }
  $first = New-Object 'System.Collections.Generic.List[object]'
  $later = New-Object 'System.Collections.Generic.List[object]'
  foreach ($p in $paths) {
    if (Test-UnderSkipped $p $Skipped) { continue }
    $kind = Get-PathAction $Local[$p] $Base[$p] $Remote[$p] -Joining:$Joining
    if ($null -eq $kind) { continue }
    $a = @{ Kind = $kind; Path = $p }
    if ($p.Contains("/projects/")) { $later.Add($a) } else { $first.Add($a) }
  }
  $first.AddRange($later)
  return ,$first.ToArray()
}

function Get-ConflictPath {
  param([string]$Path, [string]$Pc)
  return $Path + ".conflit-" + ($Pc -replace "[^A-Za-z0-9_-]", "_")
}

function Get-CaseCollisions {
  param($Paths)
  $seen = @{}
  $out = New-Object 'System.Collections.Generic.List[string]'
  foreach ($p in $Paths) {
    $k = $p.ToLowerInvariant()
    if ($seen.ContainsKey($k)) { $out.Add($p); $out.Add($seen[$k]) } else { $seen[$k] = $p }
  }
  return ,$out.ToArray()
}
