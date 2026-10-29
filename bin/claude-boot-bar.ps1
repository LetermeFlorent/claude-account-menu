. Import-ClmModule claude-display, claude-ui-palette, claude-ui-color-depth, claude-ui-console-theme, claude-ui-motion
$script:BootBarFlags = @("--no-update", "--updated", "--web")
$script:BootBarLabel = "demarrage"
$script:BootBarCells = 20
$script:BootBarWidth = 45
$script:BootBarMaxMs = 20000

$script:BootBarScript = @'
param($UiHost, $Ctl, $Loaded, [int]$Total, [string]$Label, [int]$Cells, [bool]$Motion, $Look)
$e = [string][char]27
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
    [void]$sb.Append("`r  " + $Label.PadRight(13) + $Look.Fill + ($Look.FillGlyph * $n))
    for ($i = $n; $i -lt $Cells; $i++) {
      if ($i -ge $a -and $i -lt $b) { [void]$sb.Append($Look.Sweep + $Look.EmptyGlyph) }
      else { [void]$sb.Append($Look.Empty + $Look.EmptyGlyph) }
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

function New-BootBarLook {
  param([string]$Theme, [string]$Depth)
  $fill = $script:LevelSets[$Theme]["7d"][0]
  $empty = $script:Palettes[$Theme].Empty
  $look = @{ FillGlyph = [string][char]0x25A0; EmptyGlyph = [string][char]0x25A0 }
  if ($Depth -eq "none") { $look.EmptyGlyph = [string][char]0x25A1 }
  $e = [string][char]27
  $look.Fill = $e + "[0" + (Get-ColorSgr $fill $Depth) + "m"
  $look.Empty = $e + "[0" + (Get-ColorSgr $empty $Depth) + "m"
  $look.Sweep = $e + "[0" + (Get-ColorSgr (Get-MixedRgb $empty $fill 0.5) $Depth) + "m"
  return $look
}

function Get-BootBarSetup {
  param([string]$Os = $script:OsName, $Vars = $null)
  $look = New-BootBarLook (Get-ConsoleTheme $Os $Vars) (Get-ColorDepth $Os $Vars)
  return @{ Motion = (Get-MotionEnabled $Os $Vars); Look = $look }
}

function Start-BootBar {
  param([object[]]$ArgList, [string]$Dir, $Loaded)
  if (-not (Test-BootBarWanted $ArgList)) { return $null }
  $total = [math]::Max(1, [IO.Directory]::GetFiles($Dir, "claude-*.ps1").Length)
  $ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = $script:BootBarMaxMs })
  $setup = Get-BootBarSetup
  $ps = [PowerShell]::Create()
  [void]$ps.AddScript($script:BootBarScript).AddArgument($Host).AddArgument($ctl).AddArgument($Loaded).AddArgument($total).AddArgument($script:BootBarLabel).AddArgument($script:BootBarCells).AddArgument($setup.Motion).AddArgument($setup.Look)
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
  try { [void]$Bar.Ps.EndInvoke($Bar.Handle) } catch { Write-Verbose $_.Exception.Message }
  $Bar.Ps.Dispose()
  $Bar.Ps = $null
}
