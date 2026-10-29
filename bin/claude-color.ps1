$script:ColorHex = New-Object regex '^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$'
$script:ColorInks = @("#ffffff", "#000000")
$script:ColorTextMin = 4.5
$script:ColorPartMin = 3.0
$script:AccentKey = "HKCU:\Software\Microsoft\Windows\DWM"

function ConvertFrom-HexColor {
  param([string]$Hex)
  $m = $script:ColorHex.Match(("" + $Hex).Trim())
  if (-not $m.Success) { return $null }
  return @(1..3 | ForEach-Object { [Convert]::ToInt32($m.Groups[$_].Value, 16) })
}

function Get-ColorLuminance {
  param([string]$Hex)
  $rgb = ConvertFrom-HexColor $Hex
  if ($null -eq $rgb) { return $null }
  $lin = @(foreach ($c in $rgb) {
    $s = $c / 255.0
    if ($s -le 0.04045) { $s / 12.92 } else { [math]::Pow(($s + 0.055) / 1.055, 2.4) }
  })
  return 0.2126 * $lin[0] + 0.7152 * $lin[1] + 0.0722 * $lin[2]
}

function Get-ColorContrast {
  param([string]$One, [string]$Two)
  $a = Get-ColorLuminance $One
  $b = Get-ColorLuminance $Two
  if ($null -eq $a -or $null -eq $b) { return 0.0 }
  $hi = [math]::Max($a, $b)
  $lo = [math]::Min($a, $b)
  return ($hi + 0.05) / ($lo + 0.05)
}

function ConvertFrom-AccentDword {
  param($Value)
  if ($null -eq $Value) { return "" }
  $v = [int64]$Value -band 0xffffffffL
  return "#{0:x2}{1:x2}{2:x2}" -f ($v -band 0xff), (($v -shr 8) -band 0xff), (($v -shr 16) -band 0xff)
}

function Read-WindowsAccentDword {
  try { return (Get-ItemProperty -LiteralPath $script:AccentKey -Name AccentColor -ErrorAction Stop).AccentColor } catch { return $null }
}

function Read-WindowsAccent {
  param([string]$Os = $script:OsName)
  if ($Os -ne "Windows") { return "" }
  try { return ConvertFrom-AccentDword (Read-WindowsAccentDword) } catch { return "" }
}

function Get-AccentInk {
  param([string]$Fill)
  $best = $script:ColorInks[0]
  foreach ($ink in $script:ColorInks) { if ((Get-ColorContrast $ink $Fill) -gt (Get-ColorContrast $best $Fill)) { $best = $ink } }
  return $best
}

function Get-AccentPair {
  param([string]$Hex, $Theme)
  if ($null -eq (ConvertFrom-HexColor $Hex) -or $null -eq $Theme) { return $null }
  $fill = $Hex.ToLowerInvariant()
  foreach ($back in @($Theme["bg"], $Theme["surface"], $Theme["track"])) { if ((Get-ColorContrast $fill $back) -lt $script:ColorPartMin) { return $null } }
  $ink = Get-AccentInk $fill
  if ((Get-ColorContrast $ink $fill) -lt $script:ColorTextMin) { return $null }
  return [ordered]@{ fill = $fill; ink = $ink }
}
