$script:RaceModuleCount = 30
$script:RaceFillLines = 120
$script:RaceStampA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 1760000000 1"
$script:RaceStampB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 1770000000 2"

function Write-RaceFile {
  param([string]$Path, [string[]]$Lines)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
}

function Get-RaceModuleLines {
  param([string]$Letter, [string]$Name)
  $lines = @('$script:RaceSeen = @($script:RaceSeen) + "' + $Letter + '"')
  $lines += @(for ($i = 0; $i -lt $script:RaceFillLines; $i++) { '$script:RaceFill = "' + $Name + ' ' + $Letter + ' ' + $i + '"' })
  return $lines
}

function Get-RaceEntryLines {
  param([string]$Letter, [string[]]$Modules, [string[]]$Extras)
  $lines = @(
    'if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }',
    ('$script:RaceSeen = @("' + $Letter + '")'),
    ('. Import-ClmModule ' + ($Modules -join ", ")))
  foreach ($e in $Extras) { $lines += ('. (Join-Path (Join-Path $PSScriptRoot "lib") "' + $e + '")') }
  $lines += @(
    'function Get-RaceLetters { return ((@($script:RaceSeen) | Sort-Object -Unique) -join ",") }',
    'function Get-RaceUsage { param($Account) return (Get-RaceLetters) }',
    'function Invoke-DriveSync { param($Ctl = $null, [long]$DeadlineMs = 0, [switch]$Force) return @{ Ok = $true; Seen = (Get-RaceLetters) } }',
    'function Get-SyncBytes { param([string]$Rel, [string]$Full) return (Get-RaceLetters) }',
    'function Send-SealedFile { param($Folder, $Rel, $Bytes, $Props, $Id, $Keys) return ("" + $Bytes) }')
  return $lines
}

function New-RaceTree {
  param([string]$Root, [string]$Letter)
  $modules = @(for ($n = 1; $n -le $script:RaceModuleCount; $n++) { "race-mod-" + $n.ToString("00") })
  $extras = @("race-data.ps1")
  if ($Letter -eq "B") { $modules += "race-mod-extra" } else { $extras += "race-old.ps1" }
  foreach ($m in $modules) { Write-RaceFile (Join-Path $Root ($m + ".ps1")) (Get-RaceModuleLines $Letter $m) }
  foreach ($e in $extras) { Write-RaceFile (Join-Path (Join-Path $Root "lib") $e) (Get-RaceModuleLines $Letter $e) }
  Write-RaceFile (Join-Path $Root "race-entry.ps1") (Get-RaceEntryLines $Letter $modules $extras)
  Copy-Item -LiteralPath (Join-Path $bin "claude-import.ps1") -Destination (Join-Path $Root "claude-import.ps1")
  return $Root
}

function Get-RaceFileList {
  param([string]$Root)
  $base = (Get-Item -LiteralPath $Root).FullName.TrimEnd([char[]]@('\', '/'))
  [string[]]$names = @(Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object { $_.FullName.Substring($base.Length + 1).Replace("\", "/") })
  [Array]::Sort($names, [StringComparer]::Ordinal)
  return $names
}
