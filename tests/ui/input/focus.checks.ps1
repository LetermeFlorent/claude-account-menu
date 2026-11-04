$focusKept = @{}
foreach ($n in @("Read-ConInEvent", "Write-Ui", "Enable-UiMouse", "Disable-UiMouse", "Get-UiSize", "Reset-Frame", "New-ThemeWatch")) {
  $f = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue
  $focusKept[$n] = $null
  if ($f) { $focusKept[$n] = $f.ScriptBlock }
}
$focusVars = @{}
foreach ($n in @("MouseMode", "UiOn", "UiFocused", "UiRefocus", "UiMinute", "UiCols", "UiRows", "UiClip", "LastRows", "FadeArmed", "ThemeWatch", "MotionRead", "MotionOn", "UiCtrlC")) {
  $focusVars[$n] = (Get-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue).Value
}
$script:FocusEvents = New-Object 'System.Collections.Generic.Queue[object]'
$script:FocusOut = New-Object 'System.Collections.Generic.List[string]'

function New-FocusRec {
  param([int]$Type, [int]$Down = 1, [int]$Ch = 0, [int]$Vk = 0)
  $r = New-Object 'ClmConIn+Rec'
  $r.Type = $Type
  $r.KeyDown = $Down
  $r.Vk = $Vk
  $r.Ch = $Ch
  return $r
}

function Get-FocusScan {
  param([object[]]$Recs)
  $arr = [ClmConIn+Rec[]]@($Recs)
  $focus = -2
  $used = [ClmConIn]::FocusLength($arr, $arr.Length, [ref]$focus)
  return "" + $used + " " + $focus
}

if ($script:OsName -eq "Windows") {
  if (-not ("ClmConIn" -as [type])) { Add-Type -TypeDefinition $script:ConInSource }
  Assert-Equal "1 1" (Get-FocusScan @((New-FocusRec 16 1))) "focus : evenement de focus gagne"
  Assert-Equal "1 0" (Get-FocusScan @((New-FocusRec 16 0))) "focus : evenement de focus perdu"
  $seq = @((New-FocusRec 1 1 27 27), (New-FocusRec 1 0 27 27), (New-FocusRec 1 1 91), (New-FocusRec 1 0 91), (New-FocusRec 1 1 0 16), (New-FocusRec 1 1 73), (New-FocusRec 1 0 73))
  Assert-Equal "6 1" (Get-FocusScan $seq) "focus : sequence ESC [ I lue d'un bloc"
  Assert-Equal "3 0" (Get-FocusScan @((New-FocusRec 1 1 27), (New-FocusRec 1 1 91), (New-FocusRec 1 1 79))) "focus : sequence ESC [ O lue d'un bloc"
  Assert-Equal "0 -1" (Get-FocusScan @((New-FocusRec 1 1 27 27))) "focus : Echap seule reste une touche"
  Assert-Equal "0 -1" (Get-FocusScan @((New-FocusRec 1 1 27), (New-FocusRec 1 1 91), (New-FocusRec 1 1 65))) "focus : autre sequence laissee aux touches"
  Assert-Equal "0 -1" (Get-FocusScan @((New-FocusRec 1 1 97 65))) "focus : lettre laissee aux touches"
  Assert-Equal "0 -1" (Get-FocusScan @((New-FocusRec 2 0))) "focus : souris laissee a la souris"
}

try {
  function script:Get-UiSize { return ,@(80, 24) }
  function script:Read-ConInEvent { if ($script:FocusEvents.Count -eq 0) { return $null }; return ,$script:FocusEvents.Dequeue() }
  $script:MouseMode = 0
  $script:LastRows = $null
  $script:UiFocused = $true
  $script:UiRefocus = $false
  $script:FocusEvents.Enqueue(@(4, 0))
  Assert-Null (Read-UiInput) "focus : focus perdu, aucune touche pour le menu"
  Assert-True (-not $script:UiFocused) "focus : focus perdu retenu"
  $script:FocusEvents.Enqueue(@(4, 1))
  $script:FocusEvents.Enqueue(@(2, 5, 0, 1, 0))
  $m = Read-UiInput
  Assert-Equal "click" $m.Mouse "focus : focus revenu, la souris passe ensuite"
  Assert-True $script:UiFocused "focus : focus revenu retenu"
  $script:UiMinute = [DateTime]::Now.Minute
  $s = Get-UiSize
  Set-UiSize $s
  Assert-True (Update-UiTick 0 $true) "focus : retour du focus, dessin immediat"
  $script:UiMinute = [DateTime]::Now.Minute
  Assert-True (-not (Update-UiTick 0 $true)) "focus : un seul dessin pour un retour"
  Set-UiFocus $true
  Assert-True (-not (Update-UiTick 0 $true)) "focus : deja la, rien a redessiner"
  Set-UiFocus $false
  $script:FocusEvents.Enqueue(@(2, 5, 0, 1, 0))
  $null = Read-UiInput
  Assert-True $script:UiFocused "focus : un clic prouve le focus"

  function script:Write-Ui { param([string]$Text) $script:FocusOut.Add($Text) }
  function script:Enable-UiMouse { $script:MouseMode = $script:FocusMouse }
  function script:Disable-UiMouse { $script:MouseMode = -1 }
  function script:Get-UiSize { return ,@(80, 24) }
  function script:Reset-Frame { }
  function script:New-ThemeWatch { return @{} }
  $script:MotionRead = $true
  $script:ThemeWatch = $null
  $e = $script:Esc
  $script:FocusMouse = 0
  $script:UiFocused = $false
  Enter-UiScreen
  Assert-True (($script:FocusOut -join "").Contains($e + "[?1004h")) "focus : suivi du focus active avec la souris"
  Assert-True $script:UiFocused "focus : le menu demarre avec le focus"
  $script:FocusOut.Clear()
  Exit-UiScreen
  Assert-True (($script:FocusOut -join "").Contains($e + "[?1004l")) "focus : suivi du focus coupe en rendant le terminal"
  $script:FocusOut.Clear()
  $script:FocusMouse = -1
  Enter-UiScreen
  Assert-True (-not ($script:FocusOut -join "").Contains("[?1004h")) "focus : terminal simple, pas de suivi du focus"
  Exit-UiScreen
  $restores = @(Get-ChildItem -LiteralPath $bin -Filter "*.ps1" -Recurse | Where-Object { (Get-Content -Raw -LiteralPath $_.FullName).Contains('"[?1049l"') })
  Assert-Equal "claude-ui-term.ps1" (($restores | ForEach-Object { $_.Name }) -join ",") "focus : un seul endroit rend le terminal"
} finally {
  foreach ($n in @($focusKept.Keys)) {
    if ($focusKept[$n]) { Set-Item -Path ("function:script:" + $n) -Value $focusKept[$n] }
    else { Remove-Item -Path ("function:" + $n) -ErrorAction SilentlyContinue }
  }
  foreach ($n in @($focusVars.Keys)) { Set-Variable -Name $n -Scope Script -Value $focusVars[$n] }
  if ($null -eq $focusVars["UiFocused"]) { $script:UiFocused = $true }
}
