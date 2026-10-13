function Read-JsonFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $raw = [IO.File]::ReadAllText($Path)
  if ($PSVersionTable.PSVersion.Major -ge 6) { return ConvertFrom-Json $raw -AsHashtable -Depth 100 }
  Add-Type -AssemblyName System.Web.Extensions
  $s = New-Object System.Web.Script.Serialization.JavaScriptSerializer
  $s.MaxJsonLength = [int]::MaxValue
  $s.RecursionLimit = 1000
  return $s.DeserializeObject($raw)
}

function ConvertTo-JsonString {
  param([string]$Text)
  $t = $Text.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace("`t", '\t')
  $t = [regex]::Replace($t, '[\x00-\x1f]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
  return '"' + $t + '"'
}

function ConvertTo-JsonText {
  param($Value, [string]$Indent = "")
  $next = $Indent + "  "
  if ($null -eq $Value) { return "null" }
  if ($Value -is [string]) { return ConvertTo-JsonString $Value }
  if ($Value -is [bool]) { return $Value.ToString().ToLower() }
  if ($Value -is [System.Collections.IDictionary]) {
    if ($Value.Count -eq 0) { return "{}" }
    $parts = foreach ($k in $Value.Keys) { $next + (ConvertTo-JsonString $k) + ": " + (ConvertTo-JsonText $Value[$k] $next) }
    return "{`n" + (@($parts) -join ",`n") + "`n" + $Indent + "}"
  }
  if ($Value -is [System.Collections.IEnumerable]) {
    $items = @($Value)
    if ($items.Count -eq 0) { return "[]" }
    $parts = foreach ($i in $items) { $next + (ConvertTo-JsonText $i $next) }
    return "[`n" + (@($parts) -join ",`n") + "`n" + $Indent + "]"
  }
  return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Write-JsonFile {
  param([string]$Path, $Data)
  $bak = $Path + ".bak-sync"
  if ((Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath $bak)) { [IO.File]::Copy($Path, $bak) }
  [IO.File]::WriteAllText($Path, (ConvertTo-JsonText $Data) + "`n", (New-Object Text.UTF8Encoding $false))
}
