. Import-ClmModule claude-platform, claude-json
$script:McpKeySep = "|"
$script:McpNamePattern = [regex]'^[^"\\\x00-\x1f]{1,128}$'
$script:ProjectRelPattern = [regex]'^[^|"\\:*?<>\x00-\x1f]{1,512}$'

function Test-ProjectRel {
  param([string]$Rel)
  if (-not $script:ProjectRelPattern.IsMatch($Rel)) { return $false }
  foreach ($s in $Rel.Split("/")) { if ($s -eq "" -or $s -eq "." -or $s -eq "..") { return $false } }
  return $true
}

function Join-McpKey {
  param([string]$Project, [string]$Name)
  return $Project + $script:McpKeySep + $Name
}

function Split-McpKey {
  param([string]$Key)
  $i = $Key.IndexOf($script:McpKeySep)
  if ($i -lt 0) { return @{ Project = ""; Name = $Key } }
  return @{ Project = $Key.Substring(0, $i); Name = $Key.Substring($i + 1) }
}

function Test-McpKey {
  param([string]$Key)
  if ($Key.IndexOf($script:McpKeySep) -lt 0) { return $false }
  $p = Split-McpKey $Key
  return $script:McpNamePattern.IsMatch($p.Name) -and ($p.Project -eq "" -or (Test-ProjectRel $p.Project))
}

function Get-HomeSlash {
  return $script:HomeDir.Replace("\", "/").TrimEnd("/")
}

function Get-PathComparison {
  if ($script:OsName -eq "Linux") { return [StringComparison]::Ordinal }
  return [StringComparison]::OrdinalIgnoreCase
}

function ConvertTo-ProjectRel {
  param([string]$Path)
  $head = (Get-HomeSlash) + "/"
  $p = $Path.Replace("\", "/")
  if (-not $p.StartsWith($head, (Get-PathComparison))) { return "" }
  $rel = $p.Substring($head.Length).TrimEnd("/")
  if (-not (Test-ProjectRel $rel)) { return "" }
  return $rel
}

function ConvertTo-ProjectPath {
  param([string]$Rel)
  return (Get-HomeSlash) + "/" + $Rel
}

function Test-SameProject {
  param([string]$A, [string]$B)
  return [string]::Equals($A, $B, (Get-PathComparison))
}

function New-ProjectCaseMap {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseLiteralInitializerForHashtable", "", Justification = "path case rules")]
  param()
  $comparer = [StringComparer]::OrdinalIgnoreCase
  if ((Get-PathComparison) -eq [StringComparison]::Ordinal) { $comparer = [StringComparer]::Ordinal }
  return [Collections.Hashtable]::new($comparer)
}

function Add-ProjectCase {
  param($CaseMap, $Keys)
  foreach ($k in $Keys) {
    $p = (Split-McpKey $k).Project
    if ($p -and -not $CaseMap.ContainsKey($p)) { $CaseMap[$p] = $p }
  }
}

function Convert-McpMapCase {
  param($CaseMap, $Map)
  if ($null -eq $Map) { return $null }
  $out = New-PathMap
  foreach ($k in $Map.Keys) {
    $p = Split-McpKey $k
    $key = $k
    if ($p.Project -and $CaseMap.ContainsKey($p.Project)) { $key = Join-McpKey $CaseMap[$p.Project] $p.Name }
    if (-not $out.ContainsKey($key)) { $out[$key] = $Map[$k] }
  }
  return $out
}
