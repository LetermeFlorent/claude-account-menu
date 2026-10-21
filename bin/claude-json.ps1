function Read-JsonFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return ConvertFrom-JsonText ([IO.File]::ReadAllText($Path))
}

function ConvertFrom-JsonText {
  param([string]$Raw)
  if ($PSVersionTable.PSVersion.Major -ge 6) { return ConvertFrom-Json $Raw -AsHashtable -Depth 100 }
  Add-Type -AssemblyName System.Web.Extensions
  $s = New-Object System.Web.Script.Serialization.JavaScriptSerializer
  $s.MaxJsonLength = [int]::MaxValue
  $s.RecursionLimit = 1000
  return $s.DeserializeObject($raw)
}

$script:PlainJsonText = [regex]'^[^\x00-\x1f"\\]*\z'

function ConvertTo-JsonString {
  param([string]$Text)
  if ($script:PlainJsonText.IsMatch($Text)) { return '"' + $Text + '"' }
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

function Write-TextFileAtomic {
  param([string]$Path, [string]$Text)
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  [IO.File]::WriteAllText($tmp, $Text, (New-Object Text.UTF8Encoding $false))
  if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
  else { [IO.File]::Move($tmp, $Path) }
}

function New-PathMap {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseLiteralInitializerForHashtable", "", Justification = "case-sensitive paths")]
  param()
  return [Collections.Hashtable]::new([StringComparer]::Ordinal)
}
