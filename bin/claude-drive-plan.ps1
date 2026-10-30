$script:BaseOnlyKinds = @("adopt", "forget")
$script:SettingsPathPattern = [regex]'^(\.(claude\.json|mcp\.json|claude-accounts\.json)|\.claude[^/]*/((skills|agents|commands|hooks|rules)/.+|settings\.json|settings\.local\.json|CLAUDE\.md|ANTI-EMPREINTE\.md|statusline\.json|\.claude\.json))$'

function Test-SettingsPath {
  param([string]$Path)
  return $script:SettingsPathPattern.IsMatch($Path)
}

function Get-PathAction {
  param($L, $B, $R, [switch]$Joining)
  if ($null -eq $L -and $null -eq $R) {
    if ($null -ne $B) { return "forget" }
    return $null
  }
  if ($null -ne $R -and $R.Plain) {
    if ($null -ne $L) { return "upload" }
    if ($null -ne $B -and $B.Md5 -eq $R.Md5) { return "delete-remote" }
    return "refuse"
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
  param($Request)
  $Local = $Request.Local; $Base = $Request.Base; $Remote = $Request.Remote
  $Skipped = @($Request.Skipped); $Joining = [bool]$Request.Joining; $CaseFold = [bool]$Request.CaseFold
  $paths = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::Ordinal)
  foreach ($m in @($Local, $Base, $Remote)) { if ($m.Count -gt 0) { $paths.UnionWith([string[]]@($m.Keys)) } }
  $skip = New-Object 'System.Collections.Generic.List[string]'
  foreach ($s in $Skipped) { if ($s) { $skip.Add([string]$s) } }
  if ($CaseFold) { $skip.AddRange((Get-CaseCollisions $paths)) }
  $quick = New-Object 'System.Collections.Generic.List[object]'
  $settings = New-Object 'System.Collections.Generic.List[object]'
  $first = New-Object 'System.Collections.Generic.List[object]'
  $later = New-Object 'System.Collections.Generic.List[object]'
  $anySkipped = $skip.Count -gt 0
  foreach ($p in $paths) {
    if ($anySkipped -and (Test-UnderSkipped $p $skip)) { continue }
    $l = $Local[$p]; $b = $Base[$p]; $r = $Remote[$p]
    if ($null -ne $l -and $null -ne $b -and $null -ne $r -and $l.Md5 -eq $b.Md5 -and $r.Md5 -eq $b.Md5 -and $r.Id -eq $b.Id -and -not $r.Plain) { continue }
    $kind = Get-PathAction $l $b $r -Joining:$Joining
    if ($null -eq $kind) { continue }
    $a = @{ Kind = $kind; Path = $p }
    if ($script:BaseOnlyKinds -contains $kind) { $quick.Add($a) }
    elseif (Test-SettingsPath $p) { $settings.Add($a) }
    elseif ($p.Contains("/projects/")) { $later.Add($a) }
    else { $first.Add($a) }
  }
  $quick.AddRange($settings)
  $quick.AddRange($first)
  $quick.AddRange($later)
  return ,$quick.ToArray()
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
