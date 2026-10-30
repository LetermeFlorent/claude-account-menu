. Import-ClmModule claude-display, claude-json, claude-file-io, claude-text
$script:UsagePollKey = "usagePoll"
$script:UsagePollDefaultSec = 30
$script:UsagePollMinSec = 15
$script:UsagePollMaxSec = 600

function ConvertTo-UsagePollNumber {
  param($Value)
  if ($Value -is [bool]) { return $null }
  if ($Value -isnot [ValueType] -and $Value -isnot [string]) { return $null }
  $text = ("" + $Value).Trim()
  if ($text -notmatch "^[0-9]{1,9}$") { return $null }
  return [int]$text
}

function Read-UsagePollData {
  param($Vars = $null)
  try { $data = Read-JsonFile (Get-DisplayPath $Vars) } catch { return $null }
  if ($data -isnot [Collections.IDictionary]) { return $null }
  return $data
}

function Read-UsagePollSeconds {
  param($Vars = $null)
  $data = Read-UsagePollData $Vars
  if ($null -eq $data -or @($data.Keys) -notcontains $script:UsagePollKey) { return [int]$script:UsagePollDefaultSec }
  $n = ConvertTo-UsagePollNumber $data[$script:UsagePollKey]
  if ($null -eq $n) { return [int]$script:UsagePollDefaultSec }
  return [int][Math]::Min($script:UsagePollMaxSec, [Math]::Max($script:UsagePollMinSec, $n))
}

function Set-DisplayUsagePoll {
  param($Seconds, $Vars = $null)
  $n = ConvertTo-UsagePollNumber $Seconds
  if ($null -eq $n -or $n -lt $script:UsagePollMinSec -or $n -gt $script:UsagePollMaxSec) {
    throw (Get-ClmText "ui.poll.refused" @($Seconds, $script:UsagePollMinSec, $script:UsagePollMaxSec))
  }
  $data = Read-UsagePollData $Vars
  $out = [ordered]@{}
  if ($null -ne $data) { foreach ($k in $data.Keys) { $out[$k] = $data[$k] } }
  $out[$script:UsagePollKey] = $n
  Write-TextFileAtomic (Get-DisplayPath $Vars) ((ConvertTo-JsonText $out) + "`n")
  return $n
}
