. (Join-Path $PSScriptRoot "claude-sync-catalog.ps1")
$script:SkillsRoot = ".claude/skills"

function Get-SkillOfPath {
  param([string]$Rel)
  $head = $script:SkillsRoot + "/"
  if (-not $Rel.StartsWith($head, [StringComparison]::Ordinal)) { return "" }
  $rest = $Rel.Substring($head.Length)
  $i = $rest.IndexOf("/")
  if ($i -le 0) { return "" }
  return $rest.Substring(0, $i)
}

function Get-DriveSkillNames {
  param($Listing)
  $set = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::Ordinal)
  foreach ($k in $Listing.Keys) {
    $n = Get-SkillOfPath $k
    if ($n -and (Test-SkillName $n)) { [void]$set.Add($n) }
  }
  return ,[string[]]@($set)
}

function Get-LocalSkillNames {
  $dir = Get-SyncLocalPath $script:SkillsRoot
  if (-not [IO.Directory]::Exists($dir)) { return ,[string[]]@() }
  return ,[string[]]@([IO.Directory]::GetDirectories($dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { Test-SkillName $_ })
}

function ConvertTo-WildcardLiteral {
  param([string]$Text)
  return [regex]::Replace($Text, '[*?\[\]`]', { param($m) '`' + $m.Value })
}

function Get-OffSkills {
  param($Choice)
  $out = New-Object 'System.Collections.Generic.List[string]'
  foreach ($n in $Choice.skills.Keys) { if (-not $Choice.skills[$n] -and (Test-SkillName $n)) { $out.Add($n) } }
  return ,$out.ToArray()
}

function Get-SkillExcludes {
  param($Choice)
  $names = [string[]](Get-OffSkills $Choice) + [string[]]@($Choice.Erase.skills | Where-Object { Test-SkillName $_ })
  return ,[string[]]@($names | ForEach-Object { ConvertTo-WildcardLiteral ($script:SkillsRoot + "/" + $_) })
}

function Get-SkillDriveKeys {
  param($Listing, [string]$Name)
  $head = $script:SkillsRoot + "/" + $Name + "/"
  return ,[string[]]@($Listing.Keys | Where-Object { $_.StartsWith($head, [StringComparison]::Ordinal) })
}

function Get-SkillDriveIds {
  param($Listing, [string]$Name)
  $ids = New-Object 'System.Collections.Generic.List[string]'
  foreach ($k in (Get-SkillDriveKeys $Listing $Name)) {
    $id = [string]$Listing[$k].Id
    if ($id -match $script:DriveIdPattern) { $ids.Add($id) }
  }
  return ,$ids.ToArray()
}

function Remove-LocalSkill {
  param([string]$Name)
  if (-not (Test-SkillName $Name)) { return $false }
  $dir = Get-SyncLocalPath ($script:SkillsRoot + "/" + $Name)
  $info = [IO.DirectoryInfo]$dir
  if (-not $info.Exists -or ($info.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
  Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
  return $true
}

function Remove-DriveSkill {
  param($Listing, [string]$Name, $Ctl, [long]$DeadlineMs)
  $ids = Get-SkillDriveIds $Listing $Name
  if ($ids.Count -gt 0 -and (Remove-DriveFiles $ids $Ctl $DeadlineMs) -lt $ids.Count) { return $false }
  foreach ($k in (Get-SkillDriveKeys $Listing $Name)) { $Listing.Remove($k) }
  $null = Remove-LocalSkill $Name
  return $true
}

function Update-SkillPrefs {
  param($Choice, $Listing, $Ctl, [long]$DeadlineMs)
  $erased = New-Object 'System.Collections.Generic.List[string]'
  foreach ($n in @($Choice.Erase.skills)) {
    if (-not (Test-SkillName $n) -or (Remove-DriveSkill $Listing $n $Ctl $DeadlineMs)) { $erased.Add($n) }
  }
  foreach ($n in (Get-OffSkills $Choice)) { if ((Get-SkillDriveIds $Listing $n).Count -gt 0) { $null = Remove-LocalSkill $n } }
  return ,$erased.ToArray()
}
