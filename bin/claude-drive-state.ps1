. (Join-Path $PSScriptRoot "claude-platform.ps1")
. (Join-Path $PSScriptRoot "claude-json.ps1")
$script:DriveStatePath = Join-Path (Get-HomeDir) ".clm-drive-state.json"

function Read-DriveState {
  $st = @{ At = [long]0; Root = ""; Files = (New-PathMap) }
  try { $data = Read-JsonFile $script:DriveStatePath } catch { $data = $null }
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
  $tmp = $script:DriveStatePath + ".tmp"
  [IO.File]::WriteAllText($tmp, (ConvertTo-StateText $State), (New-Object Text.UTF8Encoding $false))
  if (Test-Path -LiteralPath $script:DriveStatePath) { [IO.File]::Replace($tmp, $script:DriveStatePath, [NullString]::Value) }
  else { [IO.File]::Move($tmp, $script:DriveStatePath) }
}
