$script:AskKinds = @("skills", "mcp")
$script:AskKeepMs = [long]30 * 24 * 3600 * 1000
$script:PcNamePattern = [regex]'^[^/\\:*?"<>|\x00-\x1f]{1,64}$'

function New-AskMaps {
  return @{ skills = (New-PathMap); mcp = (New-PathMap) }
}

function Test-AskName {
  param([string]$Kind, [string]$Name)
  if ($Kind -eq "mcp") { return Test-McpKey $Name }
  return Test-SkillName $Name
}

function Test-AskMapsEmpty {
  param($Maps)
  foreach ($kind in $script:AskKinds) { if ($Maps[$kind].Count -gt 0) { return $false } }
  return $true
}

function ConvertFrom-KindMaps {
  param($Data, [scriptblock]$Value)
  $maps = New-AskMaps
  foreach ($kind in $script:AskKinds) {
    $map = $null
    if ((Get-JsonKeys $Data) -contains $kind) { $map = $Data[$kind] }
    foreach ($n in (Get-JsonKeys $map)) {
      $v = & $Value $map[$n]
      if ($null -ne $v -and (Test-AskName $kind ([string]$n))) { $maps[$kind][[string]$n] = $v }
    }
  }
  return $maps
}

function ConvertTo-KindMapsData {
  param($Maps, [scriptblock]$Value)
  $data = [ordered]@{}
  foreach ($kind in $script:AskKinds) {
    $sorted = ConvertTo-SortedMap $Maps[$kind]
    $out = [ordered]@{}
    foreach ($n in $sorted.Keys) { $out[$n] = & $Value $sorted[$n] }
    $data[$kind] = $out
  }
  return $data
}

function Read-CheckValue {
  param($Value)
  if ($Value -is [bool]) { return $Value }
  return $null
}

function Read-StampValue {
  param($Value)
  $at = ConvertTo-PositiveLong $Value
  if ($at -gt 0) { return $at }
  return $null
}

function Read-AskEntry {
  param($Data)
  if ($Data -isnot [Collections.IDictionary] -or $Data["on"] -isnot [bool]) { return $null }
  $at = ConvertTo-PositiveLong $Data["at"]
  if ($at -le 0) { return $null }
  return @{ On = $Data["on"]; At = $at }
}

function ConvertFrom-AsksData {
  param($Data)
  $asks = New-PathMap
  foreach ($pc in (Get-JsonKeys $Data)) {
    if (-not $script:PcNamePattern.IsMatch([string]$pc)) { continue }
    $maps = ConvertFrom-KindMaps $Data[$pc] { param($v) Read-AskEntry $v }
    if (-not (Test-AskMapsEmpty $maps)) { $asks[[string]$pc] = $maps }
  }
  return $asks
}

function ConvertTo-AsksData {
  param($Asks)
  $data = [ordered]@{}
  $sorted = ConvertTo-SortedMap $Asks
  foreach ($pc in $sorted.Keys) { $data[$pc] = ConvertTo-KindMapsData $sorted[$pc] { param($a) [ordered]@{ on = $a.On; at = $a.At } } }
  return $data
}

function ConvertFrom-TookData {
  param($Data)
  $took = New-PathMap
  foreach ($pc in (Get-JsonKeys $Data)) {
    $at = ConvertTo-PositiveLong $Data[$pc]
    if ($at -gt 0 -and $script:PcNamePattern.IsMatch([string]$pc)) { $took[[string]$pc] = $at }
  }
  return $took
}

function Set-ChoiceStamp {
  param($Choice, [string]$Kind, [string]$Name)
  if ($null -eq $Choice.Stamps -or $script:AskKinds -notcontains $Kind) { return }
  $Choice.Stamps[$Kind][$Name] = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}

function Add-PcAsk {
  param($Choice, [string]$Pc, [string]$Kind, [string]$Name, [bool]$On, [long]$After)
  if (-not $Choice.Asks.ContainsKey($Pc)) { $Choice.Asks[$Pc] = New-AskMaps }
  $at = [math]::Max([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(), $After + 1)
  $old = $Choice.Asks[$Pc][$Kind][$Name]
  if ($null -ne $old -and $old.At -ge $at) { $at = $old.At + 1 }
  $Choice.Asks[$Pc][$Kind][$Name] = @{ On = $On; At = [long]$at }
}

function Remove-PcAsk {
  param($Choice, [string]$Pc, [string]$Kind, [string]$Name)
  $maps = $Choice.Asks[$Pc]
  if ($null -eq $maps) { return }
  $maps[$Kind].Remove($Name)
  if (Test-AskMapsEmpty $maps) { $Choice.Asks.Remove($Pc) }
}

function Add-PendingAsks {
  param($Pending, $Maps, [long]$Took)
  if ($null -eq $Maps) { return }
  foreach ($kind in $script:AskKinds) {
    foreach ($n in $Maps[$kind].Keys) {
      $a = $Maps[$kind][$n]
      if ($a.At -le $Took) { continue }
      $cur = $Pending[$kind][$n]
      if ($null -eq $cur -or $a.At -gt $cur.At) { $Pending[$kind][$n] = $a }
    }
  }
}

function Get-PcPending {
  param($Pcs, $Choice, [string]$Me, [string]$Pc)
  $took = $Pcs[$Pc].Took
  $others = New-AskMaps
  foreach ($from in $Pcs.Keys) {
    if ($from -cne $Pc -and $from -cne $Me) { Add-PendingAsks $others $Pcs[$from].Asks[$Pc] ([long]$took[$from]) }
  }
  $mine = New-AskMaps
  Add-PendingAsks $mine $Choice.Asks[$Pc] ([long]$took[$Me])
  return @{ Others = $others; Mine = $mine }
}
