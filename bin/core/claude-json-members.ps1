$script:JsonTokenPattern = '"(?:[^"\\]|\\.)*"|[{}\[\],]'

function Get-JsonMembers {
  param([string]$Text)
  $info = $null
  $member = $null
  $depth = 0
  $expectKey = $false
  foreach ($t in [regex]::Matches($Text, $script:JsonTokenPattern)) {
    $v = $t.Value
    if ($null -eq $info) {
      if ($v -ne "{" -or $Text.Substring(0, $t.Index).Trim()) { return $null }
      $info = @{ Open = $t.Index; Close = -1; Members = (New-Object Collections.ArrayList) }
      $depth = 1
      $expectKey = $true
      continue
    }
    if ($depth -eq 1 -and $expectKey -and $v[0] -eq '"') {
      $member = @{ Name = $v.Substring(1, $v.Length - 2); Start = $t.Index; End = -1 }
      $expectKey = $false
      continue
    }
    if ($depth -eq 1 -and ($v -eq "," -or $v -eq "}")) {
      if ($null -ne $member) { $member.End = $Text.Substring(0, $t.Index).TrimEnd().Length; [void]$info.Members.Add($member) }
      $member = $null
      if ($v -eq "}") { $info.Close = $t.Index; return $info }
      $expectKey = $true
      continue
    }
    if ($v -eq "{" -or $v -eq "[") { $depth++ }
    elseif ($v -eq "}" -or $v -eq "]") { $depth--; if ($depth -lt 1) { return $null } }
  }
  return $null
}

function Find-JsonMember {
  param($Info, [string]$Name)
  if ($null -eq $Info) { return -1 }
  for ($i = 0; $i -lt $Info.Members.Count; $i++) { if ($Info.Members[$i].Name -ceq $Name) { return $i } }
  return -1
}

function Remove-JsonMember {
  param([string]$Text, $Info, [int]$Index)
  $m = $Info.Members
  if ($m.Count -eq 1) { return $Text.Substring(0, $Info.Open + 1) + $Text.Substring($Info.Close) }
  if ($Index -gt 0) { return $Text.Substring(0, $m[$Index - 1].End) + $Text.Substring($m[$Index].End) }
  return $Text.Substring(0, $m[0].Start) + $Text.Substring($m[1].Start)
}

function Add-JsonMember {
  param([string]$Text, $Info, [string]$Member)
  $m = $Info.Members
  if ($m.Count -eq 0) { return $Text.Substring(0, $Info.Open + 1) + "`n  " + $Member + "`n" + $Text.Substring($Info.Close) }
  $sep = $Text.Substring($Info.Open + 1, $m[0].Start - $Info.Open - 1)
  $at = $m[$m.Count - 1].End
  return $Text.Substring(0, $at) + "," + $sep + $Member + $Text.Substring($at)
}
