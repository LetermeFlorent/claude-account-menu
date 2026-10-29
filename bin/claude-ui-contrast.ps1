function Get-LinearChannel {
  param([double]$Value)
  $c = $Value / 255
  if ($c -le 0.04045) { return $c / 12.92 }
  return [math]::Pow(($c + 0.055) / 1.055, 2.4)
}

function Get-RelativeLuminance {
  param($Rgb)
  return 0.2126 * (Get-LinearChannel $Rgb[0]) + 0.7152 * (Get-LinearChannel $Rgb[1]) + 0.0722 * (Get-LinearChannel $Rgb[2])
}

function Get-ContrastRatio {
  param($Fore, $Back)
  $a = (Get-RelativeLuminance $Fore) + 0.05
  $b = (Get-RelativeLuminance $Back) + 0.05
  if ($a -lt $b) { return $b / $a }
  return $a / $b
}

function Get-BackgroundTheme {
  param($Rgb)
  if ($null -eq $Rgb -or @($Rgb).Count -lt 3) { return "" }
  if ((Get-ContrastRatio $Rgb @(0, 0, 0)) -gt (Get-ContrastRatio $Rgb @(255, 255, 255))) { return "light" }
  return "dark"
}
