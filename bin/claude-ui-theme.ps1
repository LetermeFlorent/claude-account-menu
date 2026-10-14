$script:InkTween = $null
$script:InkFrom = $null
$script:InkTo = $null

function New-ThemeWatch {
  param([string]$Os = $script:OsName, $Vars = $null, [double]$Now = (Get-NowMs), [scriptblock]$Probe = $null)
  if ($null -eq $Probe) { $Probe = { param($O, $V) Get-SystemTheme $O $V } }
  $fixed = $null -ne (ConvertTo-ThemeName (Read-EnvVar "STATUSLINE_BG" $Vars) -French)
  $last = $null
  if (-not $fixed) { try { $last = & $Probe $Os $Vars } catch {} }
  return @{ Fixed = $fixed; Last = $last; Next = $Now + 2000; Probe = $Probe }
}

function Update-ThemeWatch {
  param($Watch, [string]$Os = $script:OsName, $Vars = $null, [double]$Now = (Get-NowMs))
  if ($Watch.Fixed -or $Now -lt $Watch.Next) { return $null }
  $Watch.Next = $Now + 2000
  $t = $null
  try { $t = & $Watch.Probe $Os $Vars } catch {}
  if (-not $t -or $t -eq $Watch.Last) { return $null }
  $Watch.Last = $t
  return $t
}

function Set-UiTheme {
  param([string]$Name, [double]$Now)
  $to = $script:Palettes[$Name]
  if ($null -eq $to) { return }
  $script:InkFrom = $script:Ink
  $script:InkTo = $to
  $script:InkTween = New-Tween 0 1 300 $Now
}

function Update-InkFade {
  param([double]$Now)
  if ($null -eq $script:InkTween) { return $false }
  if (-not (Test-TweenRunning $script:InkTween $Now)) {
    $script:Ink = $script:InkTo
    $script:InkTween = $null
    return $true
  }
  $t = Get-TweenValue $script:InkTween $Now
  $ink = @{}
  foreach ($k in $script:InkTo.Keys) { $ink[$k] = Get-MixedRgb $script:InkFrom[$k] $script:InkTo[$k] $t }
  $script:Ink = $ink
  return $true
}
