$script:Clock = [Diagnostics.Stopwatch]::StartNew()
$script:MotionOn = $true

function Get-NowMs {
  return $script:Clock.Elapsed.TotalMilliseconds
}

function Get-EaseOut {
  param([double]$T)
  if ($T -le 0) { return 0.0 }
  if ($T -ge 1) { return 1.0 }
  $r = 1 - $T
  return 1 - $r * $r * $r
}

function Get-MixedRgb {
  param($From, $To, [double]$T)
  if ($T -le 0) { return ,$From }
  if ($T -ge 1) { return ,$To }
  return ,@([int]($From[0] + ($To[0] - $From[0]) * $T), [int]($From[1] + ($To[1] - $From[1]) * $T), [int]($From[2] + ($To[2] - $From[2]) * $T))
}

function New-Tween {
  param([double]$From, [double]$To, [double]$Ms, [double]$Now)
  if (-not $script:MotionOn) { $Ms = 0 }
  return @{ From = $From; To = $To; Ms = $Ms; Start = $Now }
}

function Get-TweenValue {
  param($Tween, [double]$Now)
  if ($Tween.Ms -le 0) { return $Tween.To }
  $t = ($Now - $Tween.Start) / $Tween.Ms
  if ($t -ge 1) { return $Tween.To }
  if ($t -le 0) { return $Tween.From }
  $r = 1 - $t
  return $Tween.From + ($Tween.To - $Tween.From) * (1 - $r * $r * $r)
}

function Test-TweenRunning {
  param($Tween, [double]$Now)
  return ($Tween.Ms -gt 0 -and $Now -lt $Tween.Start + $Tween.Ms)
}

function Set-TweenTarget {
  param($Tween, [double]$To, [double]$Ms, [double]$Now)
  $Tween.From = Get-TweenValue $Tween $Now
  $Tween.To = $To
  $Tween.Start = $Now
  $Tween.Ms = $Ms
  if (-not $script:MotionOn) { $Tween.Ms = 0 }
}

function ConvertTo-MotionFlag {
  param([string]$Os, $Raw)
  if ($null -eq $Raw) { return $true }
  $v = ("" + $Raw).Trim().ToLowerInvariant()
  if ($Os -eq "MacOS") { return ($v -ne "1") }
  return -not ($v -eq "false" -or $v -eq "0")
}

function Get-SystemMotion {
  param([string]$Os = $script:OsName)
  try {
    if ($Os -eq "Windows") {
      Add-Type -AssemblyName PresentationFramework
      $sp = "System.Windows.SystemParameters" -as [type]
      return ConvertTo-MotionFlag $Os ($sp::ClientAreaAnimation)
    }
    $r = $null
    if ($Os -eq "MacOS") { $r = Invoke-Captured "defaults" "read com.apple.universalaccess reduceMotion" 3000 }
    elseif (Get-Command gsettings -CommandType Application -ErrorAction SilentlyContinue) {
      $r = Invoke-Captured "gsettings" "get org.gnome.desktop.interface enable-animations" 3000
    }
    if ($null -eq $r -or $r.Code -ne 0) { return $true }
    return ConvertTo-MotionFlag $Os $r.Out
  } catch { return $true }
}

function Get-MotionEnabled {
  param([string]$Os = $script:OsName, $Vars = $null)
  $v = Read-EnvVar "CLM_ANIM" $Vars
  if ($v -eq "0") { return $false }
  if ($v -eq "1") { return $true }
  return Get-SystemMotion $Os
}
