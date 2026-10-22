if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-config.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-config.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-sync-asks.ps1")) { . (Join-Path $PSScriptRoot "claude-sync-asks.ps1") }
$script:SyncChoicePath = Join-Path (Get-HomeDir) ".clm-sync-choice.json"
$script:SyncChoiceLockPath = Join-Path (Get-HomeDir) ".clm-sync-choice.lock"
$script:SyncChoiceWaitMs = 5000
$script:SyncChoiceBusyText = "reglages de synchro en cours d'ecriture"
$script:SyncChoiceKinds = @("skills", "mcp", "globals")

function New-SyncChoice {
  $c = @{ Erase = @{}; Stamps = (New-AskMaps); Asks = (New-PathMap) }
  foreach ($k in $script:SyncChoiceKinds) { $c[$k] = New-PathMap; $c.Erase[$k] = New-Object 'System.Collections.Generic.List[string]' }
  return $c
}

function Get-JsonKeys {
  param($Data)
  if ($Data -isnot [Collections.IDictionary]) { return @() }
  return @($Data.Keys)
}

function Read-SyncChoice {
  $c = New-SyncChoice
  try { $data = Read-JsonFile $script:SyncChoicePath } catch { $data = $null }
  if ($data -isnot [Collections.IDictionary]) { return $c }
  if ((Get-JsonKeys $data) -contains "stamps") { $c.Stamps = ConvertFrom-KindMaps $data["stamps"] { param($v) Read-StampValue $v } }
  if ((Get-JsonKeys $data) -contains "asks") { $c.Asks = ConvertFrom-AsksData $data["asks"] }
  foreach ($kind in $script:SyncChoiceKinds) {
    $map = $null
    if ((Get-JsonKeys $data) -contains $kind) { $map = $data[$kind] }
    foreach ($n in (Get-JsonKeys $map)) { if ($map[$n] -is [bool]) { $c[$kind][[string]$n] = $map[$n] } }
    $erase = $null
    if ((Get-JsonKeys $data) -contains "erase") { $erase = $data["erase"] }
    if ((Get-JsonKeys $erase) -notcontains $kind) { continue }
    foreach ($n in @($erase[$kind])) { if ($n -is [string] -and $n -and -not $c.Erase[$kind].Contains($n)) { $c.Erase[$kind].Add($n) } }
  }
  return $c
}

function ConvertTo-SortedMap {
  param($Map)
  $keys = [string[]]@($Map.Keys)
  [Array]::Sort($keys, [StringComparer]::Ordinal)
  $out = [ordered]@{}
  foreach ($k in $keys) { $out[$k] = $Map[$k] }
  return $out
}

function Save-SyncChoice {
  param($Choice)
  $data = [ordered]@{}
  $erase = [ordered]@{}
  foreach ($kind in $script:SyncChoiceKinds) {
    $data[$kind] = ConvertTo-SortedMap $Choice[$kind]
    $erase[$kind] = [string[]]$Choice.Erase[$kind].ToArray()
  }
  $data["erase"] = $erase
  if (-not (Test-AskMapsEmpty $Choice.Stamps)) { $data["stamps"] = ConvertTo-KindMapsData $Choice.Stamps { param($v) $v } }
  if ($Choice.Asks.Count -gt 0) { $data["asks"] = ConvertTo-AsksData $Choice.Asks }
  Write-TextFileAtomic $script:SyncChoicePath ((ConvertTo-JsonText $data) + "`n")
}

function Update-SyncChoice {
  param([scriptblock]$Change)
  return Invoke-WithFileLock $script:SyncChoiceLockPath $script:SyncChoiceWaitMs $script:SyncChoiceBusyText {
    $c = Read-SyncChoice
    $null = & $Change $c
    Save-SyncChoice $c
    return $c
  }
}

function Test-SkillChecked {
  param($Choice, [string]$Name)
  if ($Choice.skills.ContainsKey($Name)) { return [bool]$Choice.skills[$Name] }
  return $true
}

function Test-McpChecked {
  param($Choice, [string]$Name, [string]$Os)
  if ($Choice.mcp.ContainsKey($Name)) { return [bool]$Choice.mcp[$Name] }
  return $Os -eq $script:OsName
}

function Test-GlobalOff {
  param($Choice, [string]$Name)
  return $Choice.Erase.globals.Contains($Name) -or ($Choice.globals.ContainsKey($Name) -and -not $Choice.globals[$Name])
}

function Set-ChoiceCheck {
  param($Choice, [string]$Kind, [string]$Name, [bool]$Checked, [bool]$Default)
  if ($Checked -eq $Default) { $Choice[$Kind].Remove($Name); return }
  $Choice[$Kind][$Name] = $Checked
}

function Add-EraseRequest {
  param($Choice, [string]$Kind, [string]$Name)
  $Choice[$Kind].Remove($Name)
  if (-not $Choice.Erase[$Kind].Contains($Name)) { $Choice.Erase[$Kind].Add($Name) }
}

function Remove-EraseRequests {
  param($Choice, [string]$Kind, [string[]]$Names)
  foreach ($n in $Names) { $null = $Choice.Erase[$Kind].Remove($n) }
}
