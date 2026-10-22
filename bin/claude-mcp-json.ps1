if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json-members.ps1")) { . (Join-Path $PSScriptRoot "claude-json-members.ps1") }
$script:McpKey = "mcpServers"
$script:JsonKeyPrefix = [regex]'^"(?:[^"\\]|\\.)*"\s*:\s*'
$script:JsonStringOrSpace = '"(?:[^"\\]|\\.)*"|\s+'

function ConvertTo-CompactJson {
  param([string]$Text)
  return [regex]::Replace($Text, $script:JsonStringOrSpace, { param($m) if ($m.Value[0] -eq '"') { $m.Value } else { "" } })
}

function Get-MemberValueText {
  param([string]$Text, $Member)
  return $script:JsonKeyPrefix.Replace($Text.Substring($Member.Start, $Member.End - $Member.Start), "", 1)
}

function Read-McpMap {
  param([string]$Text)
  $info = Get-JsonMembers $Text
  if ($null -eq $info) { return $null }
  $map = New-PathMap
  $i = Find-JsonMember $info $script:McpKey
  if ($i -lt 0) { return $map }
  $value = Get-MemberValueText $Text $info.Members[$i]
  $inner = Get-JsonMembers $value
  if ($null -eq $inner) { return $map }
  foreach ($m in $inner.Members) { $map[$m.Name] = ConvertTo-CompactJson (Get-MemberValueText $value $m) }
  return $map
}

function New-McpMember {
  param($Map)
  $names = [string[]]@($Map.Keys)
  if ($names.Count -eq 0) { return '"' + $script:McpKey + '": {}' }
  [Array]::Sort($names, [StringComparer]::Ordinal)
  $rows = foreach ($n in $names) { '    "' + $n + '": ' + $Map[$n] }
  return '"' + $script:McpKey + '": {' + "`n" + (@($rows) -join ",`n") + "`n  }"
}

function Set-McpMap {
  param([string]$Text, $Map)
  $info = Get-JsonMembers $Text
  if ($null -eq $info) { return $null }
  $member = New-McpMember $Map
  $i = Find-JsonMember $info $script:McpKey
  if ($i -lt 0) { return Add-JsonMember $Text $info $member }
  $m = $info.Members[$i]
  return $Text.Substring(0, $m.Start) + $member + $Text.Substring($m.End)
}

function Test-McpMapEqual {
  param($A, $B)
  if ($null -eq $A -or $null -eq $B) { return $null -eq $A -and $null -eq $B }
  if ($A.Count -ne $B.Count) { return $false }
  foreach ($k in $A.Keys) { if (-not $B.ContainsKey($k) -or $B[$k] -cne $A[$k]) { return $false } }
  return $true
}

function Read-McpFile {
  param([string]$Path)
  if (-not [IO.File]::Exists($Path)) { return $null }
  return Read-McpMap ([IO.File]::ReadAllText($Path))
}

function Get-MemberValueStart {
  param([string]$Text, $Member)
  return $Member.Start + $script:JsonKeyPrefix.Match($Text.Substring($Member.Start, $Member.End - $Member.Start)).Length
}

function Set-MemberValue {
  param([string]$Text, $Member, [string]$Value)
  return $Text.Substring(0, (Get-MemberValueStart $Text $Member)) + $Value + $Text.Substring($Member.End)
}

function Read-JsonTextOrEmpty {
  param([string]$Path)
  if ([IO.File]::Exists($Path)) { return [IO.File]::ReadAllText($Path) }
  return "{}"
}

function Save-EditedJson {
  param([string]$Path, [string]$New)
  if (-not $New) { throw ("fichier JSON illisible : " + [IO.Path]::GetFileName($Path)) }
  try { $null = ConvertFrom-JsonText $New } catch { throw ("MCP invalides, " + [IO.Path]::GetFileName($Path) + " garde tel quel") }
  Write-TextFileAtomic $Path $New
  if ($script:OsName -ne "Windows") { & chmod 600 $Path }
}

function Write-McpFile {
  param([string]$Path, $Map)
  Save-EditedJson $Path (Set-McpMap (Read-JsonTextOrEmpty $Path) $Map)
}
