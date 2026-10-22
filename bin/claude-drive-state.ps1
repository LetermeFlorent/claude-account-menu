if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
$script:DriveStatePath = Join-Path (Get-HomeDir) ".clm-drive-state.json"
$script:JsonPlainValue = '"([^"\\\x00-\x1f]*)"'
$script:JsonRowStart = New-Object regex '^    \{', ([Text.RegularExpressions.RegexOptions]::Multiline)
$script:StateHead = New-Object regex ('\A\{\n  "at": (-?\d+),\n  "root": ' + $script:JsonPlainValue + ',\n  "files": \[')
$script:StateRow = New-Object regex ('^    \{"p": ' + $script:JsonPlainValue + ', "md5": ' + $script:JsonPlainValue + ', "m": (-?\d+), "size": (-?\d+), "id": ' + $script:JsonPlainValue + '\},?$'), ([Text.RegularExpressions.RegexOptions]::Multiline)

function Get-JsonRows {
  param([regex]$Row, [string]$Text)
  $rows = $Row.Matches($Text)
  if ($rows.Count -ne $script:JsonRowStart.Matches($Text).Count) { return $null }
  return ,$rows
}

function Read-DriveStateRows {
  param($State, [string]$Text)
  $head = $script:StateHead.Match($Text)
  if (-not $head.Success) { return $false }
  $rows = Get-JsonRows $script:StateRow $Text
  if ($null -eq $rows) { return $false }
  $State.At = [long]$head.Groups[1].Value
  $State.Root = $head.Groups[2].Value
  foreach ($r in $rows) { $g = $r.Groups; $State.Files[$g[1].Value] = @{ Md5 = $g[2].Value; M = [long]$g[3].Value; Size = [long]$g[4].Value; Id = $g[5].Value } }
  return $true
}

function Read-DriveState {
  $st = @{ At = [long]0; Root = ""; Files = (New-PathMap) }
  try { $text = [IO.File]::ReadAllText($script:DriveStatePath) } catch { return $st }
  if (Read-DriveStateRows $st $text) { return $st }
  try { $data = ConvertFrom-JsonText $text } catch { $data = $null }
  if ($null -eq $data) { return $st }
  $st.At = [long]$data["at"]
  $st.Root = [string]$data["root"]
  foreach ($v in @($data["files"])) {
    if ($null -eq $v) { continue }
    $st.Files[[string]$v["p"]] = @{ Md5 = [string]$v["md5"]; M = [long]$v["m"]; Size = [long]$v["size"]; Id = [string]$v["id"] }
  }
  return $st
}

function ConvertTo-StateText {
  param($State)
  $keys = [string[]]@($State.Files.Keys)
  [Array]::Sort($keys, [StringComparer]::Ordinal)
  $rows = New-Object 'System.Collections.Generic.List[string]'
  foreach ($k in $keys) {
    $v = $State.Files[$k]
    $p = '"' + $k + '"'; $m = '"' + $v.Md5 + '"'; $d = '"' + $v.Id + '"'
    if (-not $script:PlainJsonText.IsMatch($k + $v.Md5 + $v.Id)) { $p = ConvertTo-JsonString $k; $m = ConvertTo-JsonString ([string]$v.Md5); $d = ConvertTo-JsonString ([string]$v.Id) }
    $rows.Add('    {"p": ' + $p + ', "md5": ' + $m + ', "m": ' + [long]$v.M + ', "size": ' + [long]$v.Size + ', "id": ' + $d + '}')
  }
  return "{`n  ""at"": " + [long]$State.At + ",`n  ""root"": " + (ConvertTo-JsonString ([string]$State.Root)) + ",`n  ""files"": [`n" + [string]::Join(",`n", $rows) + "`n  ]`n}`n"
}

function Save-DriveState {
  param($State)
  Write-TextFileAtomic $script:DriveStatePath (ConvertTo-StateText $State)
}
