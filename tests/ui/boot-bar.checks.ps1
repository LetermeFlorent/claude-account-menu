. (Join-Path $bin "claude-boot-bar.ps1")

function Invoke-BootBarFrames {
  param($Ctl, $Loaded, [int]$Total, [bool]$Motion = $false, [int]$Frames = 10)
  $script:BootOut = New-Object 'System.Collections.Generic.List[string]'
  $script:BootCtl = $Ctl
  $script:BootLeft = $Frames
  $ui = New-Object psobject
  $ui | Add-Member -MemberType ScriptMethod -Name Write -Value {
    param($Text)
    $script:BootOut.Add($Text)
    if ($Text.Contains("demarrage")) { $script:BootLeft-- }
    if ($script:BootLeft -le 0) { $script:BootCtl.Stop = $true }
  }
  & ([scriptblock]::Create($script:BootBarScript)) ([PSCustomObject]@{ UI = $ui }) $Ctl $Loaded $Total "demarrage" 20 $Motion
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
$draw = @($frames | Where-Object { $_.Contains("demarrage") })
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
$plain = @((Invoke-BootBarFrames $ctl $loaded 10 $false) | Where-Object { $_.Contains("demarrage") })
Assert-True ($plain.Count -eq 10 -and @($plain | Where-Object { $_.Contains("[0;2;38;2;") }).Count -eq 0) "barre de demarrage : sans animation, pas de reflet"
$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = 10000 })
$empty = New-Object 'System.Collections.Generic.HashSet[string]'
$moving = @((Invoke-BootBarFrames $ctl $empty 10 $true) | Where-Object { $_.Contains("demarrage") })
$ctl = [hashtable]::Synchronized(@{ Stop = $false; Ready = $false; Done = $false; MaxMs = 150 })
$cut = @((Invoke-BootBarFrames $ctl $empty 10 $false 1000) | Where-Object { $_.Contains("demarrage") })
Assert-True ($cut.Count -ge 1 -and $cut.Count -lt 1000 -and $ctl.Done) "barre de demarrage : s'arrete seule au bout du temps maximum"
Assert-True (@($moving | Where-Object { $_.Contains("[0;2;38;2;") }).Count -gt 0) "barre de demarrage : reflet qui passe avec l'animation"

Assert-True (-not (Test-BootBarWanted @("--list"))) "barre de demarrage : jamais pour une commande"
Assert-True (-not (Test-BootBarWanted @("-2"))) "barre de demarrage : jamais pour un compte lance directement"
if ([Console]::IsOutputRedirected) {
  Assert-True (-not (Test-BootBarWanted @())) "barre de demarrage : jamais quand la sortie est redirigee"
  Assert-Null (Start-BootBar @() $bin $loaded) "barre de demarrage : rien lance hors terminal"
}
Stop-BootBar $null
Set-BootBarReady $null
Assert-True $true "barre de demarrage : arret et fin de chargement sans barre, sans erreur"

$savedAnim = $env:CLM_ANIM
try {
  $env:CLM_ANIM = $null
  Assert-True (Test-BootBarMotion) "barre de demarrage : animee par defaut"
  $null = New-SandboxFile ".clm-display.json" '{ "palette": "auto", "anim": "off" }'
  Assert-True (-not (Test-BootBarMotion)) "barre de demarrage : animation coupee dans les reglages"
  $null = New-SandboxFile ".clm-display.json" '{ "anim": "on" }'
  Assert-True (Test-BootBarMotion) "barre de demarrage : animation allumee dans les reglages"
  $env:CLM_ANIM = "0"
  Assert-True (-not (Test-BootBarMotion)) "barre de demarrage : CLM_ANIM=0 coupe l'animation"
  $env:CLM_ANIM = "1"
  $null = New-SandboxFile ".clm-display.json" '{ "anim": "off" }'
  Assert-True (Test-BootBarMotion) "barre de demarrage : CLM_ANIM=1 passe avant les reglages"
} finally {
  $env:CLM_ANIM = $savedAnim
  Remove-Item -LiteralPath (Join-Path $script:Sandbox ".clm-display.json") -ErrorAction SilentlyContinue
}
