$script:WorkPage = $null

function New-TextRow {
  param([string]$Text, $Ink, [bool]$Bold = $false)
  $r = New-Row
  $r.Add(@($Text, $Ink, $Bold))
  return ,$r
}

function Get-PageRows {
  param([string]$Title, $Body, [string[]]$Pairs = @(), [string]$Sub = "")
  $w = Get-Clamped ($script:UiCols - 2) 38 100
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $rows.Add((New-Row))
  $rows.Add((Get-HeaderRow $Title $w))
  if ($Sub) { $rows.Add((New-TextRow ("  " + $Sub) $script:Ink.Dim)) }
  $rows.Add((Get-RuleRow $w))
  $rows.Add((New-Row))
  foreach ($r in $Body) { $rows.Add($r) }
  $rows.Add((New-Row))
  $rows.Add((Get-RuleRow $w))
  if ($Pairs.Count -gt 0) { foreach ($r in (Get-FooterRows $Pairs $w)) { $rows.Add($r) } }
  if ($null -ne $script:UiProgress) { $rows.Add((Get-ProgressRow $w (Get-NowMs))) }
  return ,$rows
}

function Read-PageKey {
  param([scriptblock]$Build)
  while ($true) {
    $pkNow = Get-NowMs
    $null = Update-UiTick $pkNow
    Show-UiRows (& $Build) $pkNow
    $pkKey = Read-UiKey
    if ($pkKey -is [hashtable]) { $pkKey = $null }
    if ($null -ne $pkKey -and [int]$pkKey.KeyChar -ne 3) { return $pkKey }
    if ($null -ne $pkKey -or $script:UiQuit) {
      $script:UiQuit = $true
      return New-Object System.ConsoleKeyInfo ([char]27), ([ConsoleKey]::Escape), $false, $false, $false
    }
    Start-Sleep -Milliseconds 40
  }
}

function Get-ListRows {
  param([string[]]$Items, [int]$Pos, $On = $null)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  for ($i = 0; $i -lt $Items.Count; $i++) {
    $sel = $i -eq $Pos
    $ink = $script:Ink.Dim
    if ($sel) { $ink = $script:Ink.Text }
    $r = New-Row
    $r.Add(@("    ", $ink, $false))
    if ($null -eq $On) { $r.Add(@(("" + ($i + 1) + "  "), $ink, $sel)) }
    elseif ($On[$i]) { $r.Add(@(([string][char]0x25A0 + "  "), $script:Levels["7d"][0], $false)) }
    else { $r.Add(@(([string][char]0x25A1 + "  "), $script:Ink.Empty, $false)) }
    $r.Add(@($Items[$i], $ink, $sel))
    if ($sel) { Add-MarkSeg $r }
    $rows.Add($r)
  }
  return ,$rows
}

function Select-OneRow {
  param([string]$Title, [string[]]$Items, [int]$Pos, [string[]]$Pairs, [string]$Sub = "")
  $pos = [math]::Max(0, [math]::Min($Pos, $Items.Count - 1))
  while ($true) {
    $k = Read-PageKey { Get-PageRows $Title (Get-ListRows $Items $pos) $Pairs $Sub }
    if ($k.Key -eq "UpArrow") { $pos = ($pos + $Items.Count - 1) % $Items.Count }
    elseif ($k.Key -eq "DownArrow") { $pos = ($pos + 1) % $Items.Count }
    elseif ($k.Key -eq "Enter") { return $pos }
    elseif ($k.KeyChar -match "[1-9]" -and ([int]$k.KeyChar.ToString()) -le $Items.Count) { return [int]$k.KeyChar.ToString() - 1 }
    elseif ($k.Key -eq "Escape" -or $k.KeyChar -eq "q") { return $null }
  }
}

function Show-WorkPage {
  $now = Get-NowMs
  $null = Update-UiTick $now $true
  $body = @(, (New-TextRow ("  " + $script:WorkPage.Text) $script:Ink.Dim))
  Show-UiRows (Get-PageRows $script:WorkPage.Title $body) $now
}

function Invoke-UiWork {
  param([string]$Title, [string]$Text, [scriptblock]$Work)
  Hide-Screen
  $script:WorkPage = @{ Title = $Title; Text = $Text }
  $script:UiPulse = { Show-WorkPage }
  Show-WorkPage
  try { return (& $Work) } finally { $script:UiPulse = $null; $script:UiProgress = $null; $script:UiKeys.Clear() }
}
