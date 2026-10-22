if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-mcp-json.ps1")) { . (Join-Path $PSScriptRoot "claude-mcp-json.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-mcp-keys.ps1")) { . (Join-Path $PSScriptRoot "claude-mcp-keys.ps1") }
$script:ProjectsKey = "projects"

function Get-JsonName {
  param([string]$Raw)
  if (-not $Raw.Contains("\")) { return $Raw }
  try { return [string](ConvertFrom-JsonText ('"' + $Raw + '"')) } catch { return "" }
}

function Get-ProjectsMember {
  param([string]$Text)
  $info = Get-JsonMembers $Text
  if ($null -eq $info) { return $null }
  $i = Find-JsonMember $info $script:ProjectsKey
  $value = $null
  if ($i -ge 0) { $value = Get-MemberValueText $Text $info.Members[$i] }
  return @{ Info = $info; Index = $i; Value = $value }
}

function Read-ProjectsValueMcp {
  param([string]$Projects)
  $map = New-PathMap
  $info = Get-JsonMembers $Projects
  if ($null -eq $info) { return $map }
  foreach ($m in $info.Members) {
    $rel = ConvertTo-ProjectRel (Get-JsonName $m.Name)
    if (-not $rel) { continue }
    $servers = Read-McpMap (Get-MemberValueText $Projects $m)
    if ($null -eq $servers) { continue }
    foreach ($n in $servers.Keys) { $map[(Join-McpKey $rel $n)] = $servers[$n] }
  }
  return $map
}

function Read-ProjectMcp {
  param([string]$Text)
  $p = Get-ProjectsMember $Text
  if ($null -eq $p) { return $null }
  if ($null -eq $p.Value) { return New-PathMap }
  return Read-ProjectsValueMcp $p.Value
}

function Group-McpByProject {
  param($Map)
  $out = New-PathMap
  foreach ($k in $Map.Keys) {
    $p = Split-McpKey $k
    if (-not $p.Project) { continue }
    if ($null -eq $out[$p.Project]) { $out[$p.Project] = New-PathMap }
    $out[$p.Project][$p.Name] = $Map[$k]
  }
  return $out
}

function Set-OneProject {
  param([string]$Projects, [string]$Rel, $Sub)
  $info = Get-JsonMembers $Projects
  if ($null -eq $info) { return $null }
  $names = @($info.Members | Where-Object { Test-SameProject (ConvertTo-ProjectRel (Get-JsonName $_.Name)) $Rel } | ForEach-Object { $_.Name })
  if ($names.Count -eq 0) {
    if ($Sub.Count -eq 0) { return $Projects }
    return Add-JsonMember $Projects $info ((ConvertTo-JsonString (ConvertTo-ProjectPath $Rel)) + ": {`n    " + (New-McpMember $Sub) + "`n  }")
  }
  $out = $Projects
  foreach ($n in $names) {
    $now = Get-JsonMembers $out
    $m = $now.Members[(Find-JsonMember $now $n)]
    $new = Set-McpMap (Get-MemberValueText $out $m) $Sub
    if ($null -eq $new) { return $null }
    $out = Set-MemberValue $out $m $new
  }
  return $out
}

function Get-ProjectSub {
  param($Groups, [string]$Rel)
  $sub = New-PathMap
  foreach ($g in $Groups.Keys) {
    if (-not (Test-SameProject $g $Rel)) { continue }
    foreach ($n in $Groups[$g].Keys) { if (-not $sub.ContainsKey($n)) { $sub[$n] = $Groups[$g][$n] } }
  }
  return $sub
}

function Set-ProjectMcp {
  param([string]$Text, $Map)
  $p = Get-ProjectsMember $Text
  if ($null -eq $p) { return $null }
  $out = "{}"
  if ($null -ne $p.Value) { $out = $p.Value }
  $want = Group-McpByProject $Map
  $have = Group-McpByProject (Read-ProjectsValueMcp $out)
  $rels = New-Object 'System.Collections.Generic.List[string]'
  foreach ($r in @(@($want.Keys) + @($have.Keys))) { if (@($rels | Where-Object { Test-SameProject $_ $r }).Count -eq 0) { $rels.Add($r) } }
  foreach ($rel in $rels) {
    $sub = Get-ProjectSub $want $rel
    $same = @($have.Keys | Where-Object { Test-SameProject $_ $rel })
    if ($same.Count -eq 1 -and (Test-McpMapEqual $have[$same[0]] $sub)) { continue }
    $out = Set-OneProject $out $rel $sub
    if ($null -eq $out) { return $null }
  }
  if ($null -ne $p.Value) {
    if ($out -ceq $p.Value) { return $Text }
    return Set-MemberValue $Text $p.Info.Members[$p.Index] $out
  }
  if ($out -eq "{}") { return $Text }
  return Add-JsonMember $Text $p.Info ('"' + $script:ProjectsKey + '": ' + $out)
}

function Remove-OneProjectMcp {
  param([string]$Projects)
  $info = Get-JsonMembers $Projects
  if ($null -eq $info) { return $null }
  foreach ($m in $info.Members) {
    if (-not (ConvertTo-ProjectRel (Get-JsonName $m.Name))) { continue }
    $value = Get-MemberValueText $Projects $m
    $vi = Get-JsonMembers $value
    $k = Find-JsonMember $vi $script:McpKey
    if ($k -ge 0) { return Set-MemberValue $Projects $m (Remove-JsonMember $value $vi $k) }
  }
  return $null
}

function Remove-ProjectMcp {
  param([string]$Text)
  $p = Get-ProjectsMember $Text
  if ($null -eq $p -or $null -eq $p.Value) { return $Text }
  $out = $p.Value
  while ($true) {
    $next = Remove-OneProjectMcp $out
    if ($null -eq $next) { break }
    $out = $next
  }
  if ($out -ceq $p.Value) { return $Text }
  return Set-MemberValue $Text $p.Info.Members[$p.Index] $out
}

function Write-ProjectMcpFile {
  param([string]$Path, $Map)
  Save-EditedJson $Path (Set-ProjectMcp (Read-JsonTextOrEmpty $Path) $Map)
}
