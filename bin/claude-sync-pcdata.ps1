. (Join-Path $PSScriptRoot "claude-sync-choice.ps1")
. (Join-Path $PSScriptRoot "claude-mcp-keys.ps1")
$script:McpOsPattern = [regex]'^[A-Za-z]{1,20}$'
$script:McpDefMax = 65536
$script:SkillNamePattern = [regex]'^[^/\\:*?"<>|\x00-\x1f]{1,128}$'

function Test-SkillName {
  param([string]$Name)
  return $script:SkillNamePattern.IsMatch($Name) -and $Name -ne "." -and $Name -ne ".."
}

function New-PcContent {
  return @{ Md5 = ""; Mcp = (New-PathMap); Erased = (New-PathMap) }
}

function ConvertTo-PositiveLong {
  param($Value)
  if ($Value -isnot [ValueType] -or $Value -is [bool]) { return [long]0 }
  try { $n = [long]$Value } catch { return [long]0 }
  if ($n -lt 0) { return [long]0 }
  return $n
}

function Test-McpDef {
  param([string]$Def)
  if (-not $Def.StartsWith("{") -or $Def.Length -gt $script:McpDefMax) { return $false }
  try { return (ConvertFrom-JsonText $Def) -is [Collections.IDictionary] } catch { return $false }
}

function ConvertFrom-McpEntryData {
  param($Data, [bool]$Trusted)
  if ($Data -isnot [Collections.IDictionary]) { return $null }
  $keys = Get-JsonKeys $Data
  $at = [long]0
  if ($keys -contains "at") { $at = ConvertTo-PositiveLong $Data["at"] }
  if ($at -le 0) { return $null }
  if ($keys -contains "deleted" -and $Data["deleted"] -eq $true) { return @{ At = $at; Deleted = $true; Os = ""; Def = "" } }
  foreach ($k in @("os", "def")) { if ($keys -notcontains $k -or $Data[$k] -isnot [string]) { return $null } }
  if (-not $script:McpOsPattern.IsMatch($Data["os"])) { return $null }
  if (-not $Trusted -and -not (Test-McpDef $Data["def"])) { return $null }
  return @{ At = $at; Deleted = $false; Os = $Data["os"]; Def = $Data["def"] }
}

function ConvertFrom-PcData {
  param($Data, [bool]$Trusted)
  $c = New-PcContent
  if ($Data -isnot [Collections.IDictionary]) { return $c }
  $keys = Get-JsonKeys $Data
  if ($keys -contains "md5" -and $Data["md5"] -is [string]) { $c.Md5 = $Data["md5"] }
  $mcp = $null
  if ($keys -contains "mcp") { $mcp = $Data["mcp"] }
  foreach ($k in (Get-JsonKeys $mcp)) {
    if (-not (Test-McpKey ([string]$k))) { continue }
    $e = ConvertFrom-McpEntryData $mcp[$k] $Trusted
    if ($null -ne $e) { $c.Mcp[[string]$k] = $e }
  }
  $erased = $null
  if ($keys -contains "erased") { $erased = $Data["erased"] }
  foreach ($n in (Get-JsonKeys $erased)) {
    $at = ConvertTo-PositiveLong $erased[$n]
    if ($at -gt 0 -and (Test-SkillName ([string]$n))) { $c.Erased[[string]$n] = $at }
  }
  return $c
}

function ConvertTo-McpEntryData {
  param($Entry)
  if ($Entry.Deleted) { return [ordered]@{ at = $Entry.At; deleted = $true } }
  return [ordered]@{ at = $Entry.At; os = $Entry.Os; def = $Entry.Def }
}

function ConvertTo-PcData {
  param($Content, [switch]$WithMd5)
  $mcp = [ordered]@{}
  $sorted = ConvertTo-SortedMap $Content.Mcp
  foreach ($k in $sorted.Keys) { $mcp[$k] = ConvertTo-McpEntryData $sorted[$k] }
  $data = [ordered]@{ mcp = $mcp; erased = (ConvertTo-SortedMap $Content.Erased) }
  if ($WithMd5) { $data.md5 = $Content.Md5 }
  return $data
}
