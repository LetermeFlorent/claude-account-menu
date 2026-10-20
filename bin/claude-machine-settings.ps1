. (Join-Path $PSScriptRoot "claude-platform.ps1")
. (Join-Path $PSScriptRoot "claude-json.ps1")
. (Join-Path $PSScriptRoot "claude-json-members.ps1")
$script:MachineKeys = @("statusLine")
$script:SeedFile = "claude-statusline-seed.ps1"
$script:SeedTokenPattern = '(?<="command"\s*:\s*)"(?:[^"\\]|\\.)*claude-statusline-seed\.ps1(?:[^"\\]|\\.)*"'
$script:Utf8Bom = [byte[]](0xEF, 0xBB, 0xBF)

function Get-SeedHookCommand {
  param([string]$Os)
  $seed = '"$HOME/.local/bin/' + $script:SeedFile + '"'
  if ($Os -eq "Windows") { return "powershell -NoProfile -ExecutionPolicy Bypass -File " + $seed }
  return "pwsh -NoProfile -File " + $seed
}

function Set-SeedCommand {
  param([string]$Text, [string]$Command)
  if (-not $Text.Contains($script:SeedFile)) { return $Text }
  $json = ConvertTo-JsonString $Command
  return [regex]::Replace($Text, $script:SeedTokenPattern, { param($m) $json }.GetNewClosure())
}

function Get-MachineSettings {
  param([string]$Text)
  $info = Get-JsonMembers $Text
  if ($null -eq $info) { return ,[string[]]@() }
  return ,[string[]]@($info.Members | Where-Object { $script:MachineKeys -ccontains $_.Name } | ForEach-Object { $Text.Substring($_.Start, $_.End - $_.Start) })
}

function Remove-MachineSettings {
  param([string]$Text)
  $out = $Text
  foreach ($k in $script:MachineKeys) {
    while ($out.Contains('"' + $k + '"')) {
      $info = Get-JsonMembers $out
      $i = Find-JsonMember $info $k
      if ($i -lt 0) { break }
      $out = Remove-JsonMember $out $info $i
    }
  }
  return Set-SeedCommand $out (Get-SeedHookCommand "Windows")
}

function Add-MachineSettings {
  param([string]$Text, [string[]]$Members)
  $out = $Text
  foreach ($m in $Members) {
    $info = Get-JsonMembers $out
    if ($null -eq $info) { break }
    $out = Add-JsonMember $out $info $m
  }
  return Set-SeedCommand $out (Get-SeedHookCommand $script:OsName)
}

function Test-MachineSettingsPath {
  param([string]$Rel)
  return $Rel -match '^\.claude[^/]*/settings\.json$'
}

function Test-Utf8Bom {
  param([byte[]]$Bytes)
  return $Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF
}

function ConvertFrom-SettingsBytes {
  param([byte[]]$Bytes)
  $skip = 0
  if (Test-Utf8Bom $Bytes) { $skip = 3 }
  return [Text.Encoding]::UTF8.GetString($Bytes, $skip, $Bytes.Length - $skip)
}

function Convert-SettingsBytes {
  param([byte[]]$Bytes, [string[]]$Members, [switch]$Local)
  $text = ConvertFrom-SettingsBytes $Bytes
  $new = Remove-MachineSettings $text
  if ($Local) { $new = Add-MachineSettings $new $Members }
  if ($new -ceq $text) { return ,$Bytes }
  $out = [Text.Encoding]::UTF8.GetBytes($new)
  if (Test-Utf8Bom $Bytes) { $out = [byte[]]($script:Utf8Bom + $out) }
  return ,$out
}

function Read-MachineSettings {
  param([string]$Path, [string]$Fallback = "")
  foreach ($p in @($Path, $Fallback)) {
    if ($p -and [IO.File]::Exists($p)) { return ,(Get-MachineSettings (ConvertFrom-SettingsBytes ([IO.File]::ReadAllBytes($p)))) }
  }
  return $null
}

function Update-MachineSettingsFile {
  param([string]$Path, [string[]]$Members)
  [IO.File]::WriteAllBytes($Path, (Convert-SettingsBytes ([IO.File]::ReadAllBytes($Path)) $Members -Local))
}

function Get-MachineSnapshot {
  param([string[]]$Paths, [string]$Fallback)
  $saved = @{}
  foreach ($p in $Paths) { $saved[$p] = Read-MachineSettings $p $Fallback }
  return $saved
}

function Restore-MachineSnapshot {
  param($Saved)
  foreach ($p in $Saved.Keys) { if ([IO.File]::Exists($p)) { Update-MachineSettingsFile $p $Saved[$p] } }
}
