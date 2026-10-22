$script:BootBarFlags = @("--no-update", "--updated", "--web")
$script:BootBarLabel = "demarrage"
$script:BootBarCells = 20
$script:BootBarWidth = 45
$script:BootBarMaxMs = 20000

$script:BootBarScript = @'
param($UiHost, $Ctl, $Loaded, [int]$Total, [string]$Label, [int]$Cells, [bool]$Motion)
$e = [string][char]27
$glyph = [string][char]0x25A0
$green = "38;2;83;137;119"
$shown = 0.0
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
  $UiHost.UI.Write($e + "[?25l")
  while (-not $Ctl.Stop -and $sw.ElapsedMilliseconds -lt $Ctl.MaxMs) {
    $target = [math]::Min(0.9, $Loaded.Count / [double]$Total)
    if ($Ctl.Ready) { $target = 0.97 }
    $shown += ($target - $shown) * 0.15
    $n = [int][math]::Floor($shown * $Cells + 0.5)
    $w = 3
    $a = $Cells; $b = $Cells
    if ($Motion) { $a = [int][math]::Floor(($sw.ElapsedMilliseconds % 1200) / 1200 * ($Cells + $w)) - $w; $b = $a + $w }
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append("`r  " + $Label.PadRight(13) + $e + "[0;" + $green + "m" + ($glyph * $n))
    for ($i = $n; $i -lt $Cells; $i++) {
      if ($i -ge $a -and $i -lt $b) { [void]$sb.Append($e + "[0;2;" + $green + "m" + $glyph) }
      else { [void]$sb.Append($e + "[0;2m" + $glyph) }
    }
    [void]$sb.Append($e + "[0m  " + ("" + [int][math]::Round($shown * 100) + "%").PadLeft(4) + $e + "[K")
    $UiHost.UI.Write($sb.ToString())
    [Threading.Thread]::Sleep(33)
  }
} finally {
  $UiHost.UI.Write("`r" + $e + "[0m" + $e + "[2K" + $e + "[?25h")
  $Ctl.Done = $true
}
'@

function Test-BootBarWanted {
  param([object[]]$ArgList)
  foreach ($a in $ArgList) { if ($script:BootBarFlags -notcontains [string]$a) { return $false } }
  try {
    if ($Host.Name -ne "ConsoleHost") { return $false }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $false }
    if (-not $Host.UI.SupportsVirtualTerminal) { return $false }
    return [Console]::WindowWidth -ge $script:BootBarWidth
  } catch { return $false }
}

function Test-BootBarMotion {
  if ($env:CLM_ANIM -eq "0") { return $false }
  if ($env:CLM_ANIM -eq "1") { return $true }
  $dir = $env:USERPROFILE
  if (-not $dir) { $dir = $env:HOME }
  try { $text = [IO.File]::ReadAllText((Join-Path $dir ".clm-display.json")) } catch { return $true }
  return $text -notmatch '"anim"\s*:\s*"(off|0)"'
}

function Start-BootBar {
  param([object[]]$ArgList, [string]$Dir, $Loaded)
  if (-not (Test-BootBarWanted $ArgList)) { return $null }
  $total = [math]::Max(1, [IO.Directory]::GetFiles($Dir, "claude-*.ps1").Length)
  $ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = $script:BootBarMaxMs })
  $ps = [PowerShell]::Create()
  [void]$ps.AddScript($script:BootBarScript).AddArgument($Host).AddArgument($ctl).AddArgument($Loaded).AddArgument($total).AddArgument($script:BootBarLabel).AddArgument($script:BootBarCells).AddArgument((Test-BootBarMotion))
  return @{ Ps = $ps; Handle = $ps.BeginInvoke(); Ctl = $ctl }
}

function Set-BootBarReady {
  param($Bar = $script:BootBar)
  if ($null -ne $Bar) { $Bar.Ctl.Ready = $true }
}

function Stop-BootBar {
  param($Bar = $script:BootBar)
  if ($null -eq $Bar -or $null -eq $Bar.Ps) { return }
  $Bar.Ctl.Stop = $true
  try { [void]$Bar.Ps.EndInvoke($Bar.Handle) } catch {}
  $Bar.Ps.Dispose()
  $Bar.Ps = $null
}
