. Import-ClmModule claude-platform, claude-ui-palette, claude-ui-contrast
$script:TrueColorPrograms = @("iTerm.app", "WezTerm", "vscode", "ghostty")
$script:Ansi16Roles = @{ Text = "39"; Dim = "2"; Empty = "90"; Cell = "90"; Alert = "31" }
$script:Ansi16Levels = @{ "5h" = @("34", "35", "31"); "7d" = @("32", "33", "31") }
$script:Ansi16Hues = @(@(205, 0, 0, "31"), @(0, 205, 0, "32"), @(205, 205, 0, "33"), @(0, 0, 238, "34"), @(205, 0, 205, "35"), @(0, 205, 205, "36"))
$script:Ansi16Map = $null

function Get-ColorDepth {
  param([string]$Os = $script:OsName, $Vars = $null)
  if ((Read-EnvVar "NO_COLOR" $Vars) -ne "") { return "none" }
  if ($Os -eq "Windows") { return "truecolor" }
  $term = (Read-EnvVar "TERM" $Vars).ToLowerInvariant()
  if ($term -eq "dumb") { return "none" }
  if (@("truecolor", "24bit") -contains (Read-EnvVar "COLORTERM" $Vars).ToLowerInvariant()) { return "truecolor" }
  if ($script:TrueColorPrograms -contains (Read-EnvVar "TERM_PROGRAM" $Vars)) { return "truecolor" }
  if ($term -match "direct|truecolor|24bit|kitty") { return "truecolor" }
  if ($term -match "256") { return "256" }
  return "16"
}

function Get-RgbKey {
  param($Rgb)
  return "" + [int]$Rgb[0] + "," + [int]$Rgb[1] + "," + [int]$Rgb[2]
}

function Get-Ansi16Map {
  if ($null -ne $script:Ansi16Map) { return $script:Ansi16Map }
  $map = @{}
  foreach ($p in $script:Palettes.Values) { foreach ($k in $script:Ansi16Roles.Keys) { $map[(Get-RgbKey $p[$k])] = $script:Ansi16Roles[$k] } }
  foreach ($set in $script:LevelSets.Values) {
    foreach ($kind in $script:Ansi16Levels.Keys) {
      for ($i = 0; $i -lt 3; $i++) { $map[(Get-RgbKey $set[$kind][$i])] = $script:Ansi16Levels[$kind][$i] }
    }
  }
  $script:Ansi16Map = $map
  return $map
}

function Get-NearestNeutral {
  param($Rgb)
  $ink = $script:Ink
  if ($null -eq $ink) { $ink = $script:Palettes["dark"] }
  $best = "39"; $gap = [double]::MaxValue
  foreach ($k in @("Text", "Dim", "Empty")) {
    $d = [math]::Abs((Get-RelativeLuminance $Rgb) - (Get-RelativeLuminance $ink[$k]))
    if ($d -lt $gap) { $gap = $d; $best = $script:Ansi16Roles[$k] }
  }
  return $best
}

function Get-NearestHue {
  param($Rgb)
  $best = "31"; $gap = [double]::MaxValue
  foreach ($h in $script:Ansi16Hues) {
    $d = 0.0
    for ($k = 0; $k -lt 3; $k++) { $d += ($Rgb[$k] - $h[$k]) * ($Rgb[$k] - $h[$k]) }
    if ($d -lt $gap) { $gap = $d; $best = $h[3] }
  }
  return $best
}

function ConvertTo-Ansi16 {
  param($Rgb)
  $code = (Get-Ansi16Map)[(Get-RgbKey $Rgb)]
  if ($code) { return $code }
  $hi = [math]::Max([math]::Max($Rgb[0], $Rgb[1]), $Rgb[2])
  $lo = [math]::Min([math]::Min($Rgb[0], $Rgb[1]), $Rgb[2])
  if ($hi - $lo -lt 40) { return Get-NearestNeutral $Rgb }
  return Get-NearestHue $Rgb
}

function Get-CubeIndex {
  param([int]$Value)
  if ($Value -lt 48) { return 0 }
  if ($Value -lt 115) { return 1 }
  return [int][math]::Floor(($Value - 35) / 40)
}

function ConvertTo-Ansi256 {
  param($Rgb)
  $r = [int]$Rgb[0]; $g = [int]$Rgb[1]; $b = [int]$Rgb[2]
  if ($r -eq $g -and $g -eq $b) {
    if ($r -lt 8) { return 16 }
    if ($r -gt 238) { return 231 }
    return 232 + [int][math]::Round(($r - 8) / 10)
  }
  return 16 + 36 * (Get-CubeIndex $r) + 6 * (Get-CubeIndex $g) + (Get-CubeIndex $b)
}

function Get-ColorSgr {
  param($Rgb, [string]$Depth = $script:UiColorDepth)
  if ($Depth -eq "none") { return "" }
  if ($Depth -eq "16") { return ";" + (ConvertTo-Ansi16 $Rgb) }
  if ($Depth -eq "256") { return ";38;5;" + (ConvertTo-Ansi256 $Rgb) }
  return ";38;2;" + [int]$Rgb[0] + ";" + [int]$Rgb[1] + ";" + [int]$Rgb[2]
}

$script:UiColorDepth = Get-ColorDepth
