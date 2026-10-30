. (Join-Path $bin "claude-boot-bar.ps1")
$script:BootLook = New-BootBarLook "dark" "truecolor"

function Invoke-BootBarFrames {
  param($Ctl, $Loaded, [int]$Total, [bool]$Motion = $false, [int]$Frames = 10)
  $script:BootOut = New-Object 'System.Collections.Generic.List[string]'
  $script:BootCtl = $Ctl
  $script:BootLeft = $Frames
  $ui = New-Object psobject
  $ui | Add-Member -MemberType ScriptMethod -Name Write -Value {
    param($Text)
    $script:BootOut.Add($Text)
    if ($Text.Contains((Get-ClmText "menu.boot.starting"))) { $script:BootLeft-- }
    if ($script:BootLeft -le 0) { $script:BootCtl.Stop = $true }
  }
  & ([scriptblock]::Create($script:BootBarScript)) ([PSCustomObject]@{ UI = $ui }) $Ctl $Loaded $Total (Get-ClmText "menu.boot.starting") 20 $Motion $script:BootLook
  return ,$script:BootOut.ToArray()
}

function Get-BootPcts {
  param([string[]]$Frames)
  return @(foreach ($f in $Frames) { if ($f -match '(\d+)%') { [int]$Matches[1] } })
}

$sq = [string][char]0x25A0
$esc = [string][char]27
$loaded = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($n in 1..5) { [void]$loaded.Add("f" + $n) }

$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = 10000 })
$frames = Invoke-BootBarFrames $ctl $loaded 10
$draw = @($frames | Where-Object { $_.Contains((Get-ClmText "menu.boot.starting")) })
Assert-True ($draw.Count -eq 10) "barre de demarrage : une image par tour jusqu'a l'arret"
Assert-Equal ($esc + "[?25l") $frames[0] "barre de demarrage : curseur cache d'abord"
Assert-Equal ("`r" + $esc + "[0m" + $esc + "[2K" + $esc + "[?25h") $frames[$frames.Count - 1] "barre de demarrage : ligne effacee et curseur rendu a la fin"
Assert-True $ctl.Done "barre de demarrage : fin signalee"
Assert-True (@($draw | Where-Object { ($_.Length - $_.Replace($sq, "").Length) -ne 20 }).Count -eq 0) "barre de demarrage : vingt cases par image"
$p = Get-BootPcts $draw
Assert-True ($p[0] -gt 0 -and $p[$p.Count - 1] -le 50) "barre de demarrage : avance vers la part des fichiers charges"
Assert-True (@(for ($i = 1; $i -lt $p.Count; $i++) { if ($p[$i] -lt $p[$i - 1]) { $i } }).Count -eq 0) "barre de demarrage : ne recule jamais"

foreach ($n in 6..10) { [void]$loaded.Add("f" + $n) }
$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = 10000 })
$p = Get-BootPcts (Invoke-BootBarFrames $ctl $loaded 10 $false 40)
Assert-True ($p[$p.Count - 1] -gt 50 -and $p[$p.Count - 1] -le 90) "barre de demarrage : 90 % au plus tant que le chargement n'est pas fini"
$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $true; Done = $false; MaxMs = 10000 })
$p = Get-BootPcts (Invoke-BootBarFrames $ctl $loaded 10 $false 40)
Assert-True ($p[$p.Count - 1] -gt 90 -and $p[$p.Count - 1] -le 97) "barre de demarrage : presque pleine une fois tout charge, jamais 100 %"

$ctl = [hashtable]::Synchronized(@{ Stop = $true; Ready = $false; Done = $false; MaxMs = 10000 })
$frames = Invoke-BootBarFrames $ctl $loaded 10
Assert-True ($frames.Count -eq 2 -and $ctl.Done) "barre de demarrage : arretee avant la premiere image, rien de dessine"

$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = 10000 })
$plain = @((Invoke-BootBarFrames $ctl $loaded 10 $false) | Where-Object { $_.Contains((Get-ClmText "menu.boot.starting")) })
Assert-True ($plain.Count -eq 10 -and @($plain | Where-Object { $_.Contains($script:BootLook.Sweep) }).Count -eq 0) "barre de demarrage : sans animation, pas de reflet"
$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = 10000 })
$empty = New-Object 'System.Collections.Generic.HashSet[string]'
$moving = @((Invoke-BootBarFrames $ctl $empty 10 $true) | Where-Object { $_.Contains((Get-ClmText "menu.boot.starting")) })
$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = 150 })
$cut = @((Invoke-BootBarFrames $ctl $empty 10 $false 1000) | Where-Object { $_.Contains((Get-ClmText "menu.boot.starting")) })
Assert-True ($cut.Count -ge 1 -and $cut.Count -lt 1000 -and $ctl.Done) "barre de demarrage : s'arrete seule au bout du temps maximum"
Assert-True (@($moving | Where-Object { $_.Contains($script:BootLook.Sweep) }).Count -gt 0) "barre de demarrage : reflet qui passe avec l'animation"

Assert-True (-not (Test-BootBarWanted @("--list"))) "barre de demarrage : jamais pour une commande"
Assert-True (-not (Test-BootBarWanted @("-2"))) "barre de demarrage : jamais pour un compte lance directement"
if ([Console]::IsOutputRedirected) {
  Assert-True (-not (Test-BootBarWanted @())) "barre de demarrage : jamais quand la sortie est redirigee"
  Assert-Null (Start-BootBar @() $bin $loaded) "barre de demarrage : rien lance hors terminal"
}
Stop-BootBar $null
Set-BootBarReady $null
Assert-True $true "barre de demarrage : arret et fin de chargement sans barre, sans erreur"

Assert-True ($script:BootLook.Fill.Contains("38;2;" + ($script:LevelSets["dark"]["7d"][0] -join ";") + "m")) "barre de demarrage : cases pleines dans la couleur du theme"
Assert-True ($script:BootLook.Empty.Contains("38;2;" + ($script:Palettes["dark"].Empty -join ";") + "m")) "barre de demarrage : cases vides dans la couleur du theme sombre"
Assert-True ((New-BootBarLook "light" "truecolor").Empty.Contains("38;2;" + ($script:Palettes["light"].Empty -join ";") + "m")) "barre de demarrage : cases vides dans la couleur du theme clair"
$plainLook = New-BootBarLook "dark" "none"
Assert-True (-not ($plainLook.Fill + $plainLook.Empty + $plainLook.Sweep).Contains("38;")) "barre de demarrage : NO_COLOR, aucune couleur"
Assert-True ($plainLook.EmptyGlyph -ne $plainLook.FillGlyph) "barre de demarrage : NO_COLOR, cases vides d'un autre dessin"
Assert-Equal ([string][char]27 + "[0;32m") (New-BootBarLook "dark" "16").Fill "barre de demarrage : 16 couleurs, cases pleines en vert"
$bootSource = [IO.File]::ReadAllText((Join-Path $bin "claude-boot-bar.ps1"))
Assert-True (-not $bootSource.Contains("83;137;119")) "barre de demarrage : pas de couleur recopiee"
Assert-True (-not $bootSource.Contains("CLM_ANIM")) "barre de demarrage : reglage d'animation lu par Get-MotionEnabled"

$savedAnim = $env:CLM_ANIM
$bootDisplay = Join-Path (Get-StateDir) "display.json"
try {
  $env:CLM_ANIM = $null
  [IO.File]::WriteAllText($bootDisplay, '{ "palette": "light", "anim": "off" }')
  $setup = Get-BootBarSetup
  Assert-True (-not $setup.Motion) "barre de demarrage : animation coupee dans les reglages"
  Assert-Equal (New-BootBarLook "light" (Get-ColorDepth)).Empty $setup.Look.Empty "barre de demarrage : palette fixee dans les reglages"
  [IO.File]::WriteAllText($bootDisplay, '{ "anim": "on" }')
  Assert-True (Get-BootBarSetup).Motion "barre de demarrage : animation allumee dans les reglages"
  $env:CLM_ANIM = "0"
  Assert-True (-not (Get-BootBarSetup).Motion) "barre de demarrage : CLM_ANIM=0 coupe l'animation"
  $env:CLM_ANIM = "1"
  [IO.File]::WriteAllText($bootDisplay, '{ "anim": "off" }')
  Assert-True (Get-BootBarSetup).Motion "barre de demarrage : CLM_ANIM=1 passe avant les reglages"
} finally {
  $env:CLM_ANIM = $savedAnim
  Remove-Item -LiteralPath $bootDisplay -ErrorAction SilentlyContinue
}
