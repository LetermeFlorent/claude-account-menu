$script:UiOn = $false
$script:UiCtrlC = $false
$script:UiMinute = -1
$script:ThemeWatch = $null
$script:MotionRead = $false

function Test-RichTerminal {
  try {
    if ($Host.Name -ne "ConsoleHost") { return $false }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $false }
    return [bool]$Host.UI.SupportsVirtualTerminal
  } catch { return $false }
}

function Write-Ui {
  param([string]$Text)
  $Host.UI.Write($Text)
}

function Get-UiSize {
  try { return ,@([Console]::WindowWidth, [Console]::WindowHeight) } catch { return ,@(80, 24) }
}

function Set-UiSize {
  param($Size)
  $script:UiCols = [math]::Max(1, [int]$Size[0])
  $script:UiRows = [math]::Max(1, [int]$Size[1])
  $script:UiClip = [math]::Max(1, $script:UiCols - 1)
}

function Enter-UiScreen {
  if (-not $script:MotionRead) { $script:MotionOn = Get-MotionEnabled; $script:MotionRead = $true }
  try { $script:UiCtrlC = [Console]::TreatControlCAsInput; [Console]::TreatControlCAsInput = $true } catch { Write-Verbose $_.Exception.Message }
  Set-UiSize (Get-UiSize)
  $e = $script:Esc
  Write-Ui ($e + "[?1049h" + $e + "[?25l" + $e + "[0m" + $e + "[2J")
  Reset-Frame
  $script:LastRows = $null
  $script:FadeArmed = $true
  $script:UiOn = $true
  Enable-UiMouse
  if ($null -eq $script:ThemeWatch) { $script:ThemeWatch = New-ThemeWatch $script:OsName $null (Get-NowMs) }
}

function Exit-UiScreen {
  if (-not $script:UiOn) { return }
  $script:UiOn = $false
  Disable-UiMouse
  $e = $script:Esc
  Write-Ui ($e + "[0m" + $e + "[?2026l" + $e + "[?25h" + $e + "[?1049l")
  try { [Console]::TreatControlCAsInput = $script:UiCtrlC } catch { Write-Verbose $_.Exception.Message }
}

function Update-UiTick {
  param([double]$Now, [bool]$Busy = $false)
  $redraw = $false
  $s = Get-UiSize
  if ($s[0] -ne $script:UiCols -or $s[1] -ne $script:UiRows) {
    Set-UiSize $s
    Write-Ui ($script:Esc + "[2J")
    Reset-Frame
    $redraw = $true
  }
  if (-not $Busy -and $null -ne $script:ThemeWatch) {
    $t = Update-ThemeWatch $script:ThemeWatch $script:OsName $null $Now
    if ($t) { Set-UiTheme $t $Now }
  }
  if (Update-InkFade $Now) { $redraw = $true }
  $m = [DateTime]::Now.Minute
  if ($m -ne $script:UiMinute) { $script:UiMinute = $m; $redraw = $true }
  return $redraw
}
