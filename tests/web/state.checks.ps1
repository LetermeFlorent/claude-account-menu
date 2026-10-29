. (Join-Path $bin "claude-menu-remove.ps1")
. (Join-Path $bin "claude-menu-prefs.ps1")
. (Join-Path $bin "claude-menu-save.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")
. (Join-Path $bin "claude-cli.ps1")
. (Join-Path $bin "claude-web-state.ps1")
. (Join-Path $bin "claude-web-lists.ps1")

$webMocked = @("Get-DrivePcName", "Test-DriveAuto", "Test-DriveConnected", "Read-CliPrefs", "Get-DownloadsDir")
$webKept = @{}
foreach ($n in $webMocked) { $webKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$webSaved = @{ Menu = $script:MenuState; Drive = $script:DriveJob; Ink = $script:Ink; InkTo = $script:InkTo; Check = $script:ClmCheck; Startup = $script:Startup }
function Get-DrivePcName { return "bureau" }
function Test-DriveAuto { return $true }
$script:WebDriveOn = $false
function Test-DriveConnected { return $script:WebDriveOn }
$webDl = Join-Path $script:Sandbox "web-dl"
New-Item -ItemType Directory -Path $webDl -Force | Out-Null
function Get-DownloadsDir { return $webDl }

function New-WebTestEntry {
  param([string]$Label, [string]$Dir, $P5, $P7, $Err = $null, [bool]$Seen = $true)
  $acc = [PSCustomObject]@{ Label = $Label; Dir = $Dir }
  $u = [PSCustomObject]@{
    Label = $Label; Email = ($Label + "@mail.fr"); Acc = $acc; Plan = "Max"; Pct5 = $P5; Reset5 = [DateTimeOffset]::Now.AddMinutes(150).ToString("o")
    Pct7 = $P7; Reset7 = [DateTimeOffset]::Now.AddDays(3).ToString("o"); Error = $Err; Age = $null; Expired = $false; LimitedUntil = $null
  }
  return @{ Acc = $acc; U = $u; Pending = -not $Seen; Seen = $Seen }
}

try {
  $script:Ink = $script:Palettes["light"]
  $script:InkTo = $null
  $script:ClmCheck = $null
  $script:Startup = $null
  $script:DriveJob = $null
  $script:MenuState = $null
  $s = Get-WebState $true
  Assert-Equal 0 @($s.accounts).Count "web etat : sans menu, aucun compte"
  Assert-True (-not $s.drive.connected) "web etat : Drive absent"

  $script:MenuState = @{
    Entries = @((New-WebTestEntry "perso" ".claude" 42 100), (New-WebTestEntry "Pro" ".claude-compte2" 10 20 "jeton expire"), (New-WebTestEntry "neuf" ".claude-compte3" $null $null $null $false))
    Sel = 1; Msg = @("  Pro renomme", $script:Levels["7d"][0]); Version = "clm v9"
  }
  $s = Get-WebState $true
  $a = @($s.accounts)
  Assert-Equal "1 perso .claude perso@mail.fr Max" ("" + $a[0].n + " " + $a[0].label + " " + $a[0].dir + " " + $a[0].email + " " + $a[0].plan) "web etat : fiche du compte"
  Assert-Equal "42 100" ("" + $a[0].q5.pct + " " + $a[0].q7.pct) "web etat : quotas en pour cent"
  Assert-Equal (Get-ClmText "menu.usage.quota_7d_reached") $a[0].badge "web etat : quota atteint signale"
  Assert-True ($a[0].q5.left -match '^[0-9]h[0-9]{2}m$') "web etat : temps restant 5h"
  Assert-True ($a[0].q7.left -match '^[0-9]d[0-9]{2}h$') "web etat : temps restant 7d"
  Assert-Equal "epuise alert" ($a[0].q7.pace + " " + $a[0].q7.tone) "web etat : rythme du quota plein"
  Assert-True ((-not $a[0].selected) -and $a[1].selected) "web etat : compte choisi dans le terminal"
  Assert-True ((-not $a[0].erasable) -and $a[1].erasable) "web etat : dossier .claude jamais efface"
  Assert-Equal "jeton expire" $a[1].error "web etat : erreur de lecture"
  Assert-Null $a[0].error "web etat : pas d'erreur"
  Assert-True ($a[2].pending -and -not $a[2].seen) "web etat : compte en cours de lecture"
  Assert-Null $a[2].q5.pct "web etat : quota inconnu vide"
  Assert-Equal "Pro renomme ok" ($s.msg.text + " " + $s.msg.tone) "web etat : message du terminal"
  Assert-Equal "clm v9" $s.version "web etat : version"
  Assert-True ($s.open -and -not $s.startup -and -not $s.update.ready) "web etat : menu libre, rien en attente"
  Assert-True (-not (Get-WebState $false).open) "web etat : terminal occupe"
  $script:MenuState.Msg = @("  panne", $script:Palettes["dark"].Alert)
  Assert-Equal "alert" (Get-WebState $true).msg.tone "web etat : message d'erreur"
  $script:MenuState.Msg = @("  rien", $script:Ink.Dim)
  Assert-Equal "dim" (Get-WebState $true).msg.tone "web etat : message neutre"

  $script:DriveJob = New-DriveJob $true 0
  $d = (Get-WebState $true).drive
  Assert-Equal "True bureau True sync jamais False" ("" + $d.connected + " " + $d.pc + " " + $d.auto + " " + $d.tag + " " + $d.running) "web etat : Drive connecte"
  $script:DriveJob.Away[".claude-compte2"] = "portable"
  Assert-Equal "ouvert sur portable" @((Get-WebState $true).accounts)[1].away "web etat : compte ouvert ailleurs"

  $script:ClmCheck = @{ Latest = @{ Number = 12; Sha = "abcdef123456" } }
  $u = (Get-WebState $true).update
  Assert-Equal "True v12" ("" + $u.ready + " " + $u.latest) "web etat : mise a jour prete"
  $script:Startup = @{ Steps = @(@{ Name = "claude"; State = "run" }) }
  Assert-True (Get-WebState $true).startup "web etat : demarrage en cours"
  $script:Startup = $null

  $v = (Get-WebState $true).display
  Assert-Equal "auto auto False False" ($v.palette + " " + $v.anim + " " + $v.paletteEnv + " " + $v.animEnv) "web etat : affichage par defaut"
  $lk = (Get-WebState $true).look
  Assert-Equal "system light" ($lk.themePref + " " + (ConvertTo-WebTheme $lk.themePref "")) "web etat : apparence de la page fournie, claire sans theme systeme"
  try {
    $env:STATUSLINE_BG = "clair"
    $env:CLM_ANIM = "0"
    $v = (Get-WebState $true).display
    Assert-True ($v.paletteEnv -and $v.animEnv) "web etat : variables d'environnement signalees"
  } finally { Remove-Item Env:STATUSLINE_BG, Env:CLM_ANIM -ErrorAction SilentlyContinue }

  $back = ConvertFrom-JsonText (ConvertTo-JsonText (Get-WebState $true))
  Assert-Equal "42" $back["accounts"][0]["q5"]["pct"] "web etat : json relu"
  Assert-Null $back["accounts"][2]["q5"]["pct"] "web etat : quota inconnu en null"

  $p = Get-WebPrefs
  Assert-True (-not $p.connected -and @($p.lines).Count -eq 0) "web listes : reglages sans Drive"
  Assert-True ($p.warn["skills"] -like "Le skill part a la corbeille*") "web listes : avertissement d'effacement"
  $script:WebDriveOn = $true
  function Read-CliPrefs {
    $skill = New-PrefsItem "skills" "dessin" "dessin" "" $true $false
    $mcp = New-PrefsItem "mcp" "|chrome" "chrome" "perso, Windows" $false $true
    $all = New-PrefsAll "mcp" "tous les MCP" @($mcp)
    return @{ Catalog = @{ Waiting = @(); PerPc = $true }; Lines = @((New-PrefsHead "Skills"), $skill, (New-PrefsHead "MCP"), $all, $mcp) }
  }
  $p = Get-WebPrefs
  $l = @($p.lines)
  Assert-Equal "head item head item item" (@($l | ForEach-Object { $_.type }) -join " ") "web listes : lignes des reglages"
  Assert-Equal "skill:dessin True False" ($l[1].id + " " + $l[1].on + " " + $l[1].erasing) "web listes : skill coche"
  Assert-Equal "mcp:|chrome perso, Windows True" ($l[4].id + " " + $l[4].tag + " " + $l[4].erasing) "web listes : MCP en cours d'effacement"
  Assert-True $l[3].all "web listes : case de groupe"
  Assert-Equal $script:PrefsOffWarn.skills.Trim() (@($l[1].off) -join "|") "web listes : texte montre avant de decocher"
  Assert-Equal 0 @($l[4].off).Count "web listes : MCP en cours d'effacement, rien a decocher"
  Assert-True ((ConvertTo-JsonText $p) -match '"off"\s*:\s*\[\s*"Le skill') "web listes : texte avant de decocher envoye en liste"
  Assert-Equal "case cochee : synchronise sur ce PC" $p.sub "web listes : explication"
  Assert-Equal "bureau 0" ($p.me + " " + @($p.pcs).Count) "web listes : ce PC seul"

  Assert-Equal 0 @((Get-WebBackups).items).Count "web listes : aucune sauvegarde"
  $f1 = Join-Path $webDl "claude-comptes-20261001-100000.zip"
  $f2 = Join-Path $webDl "claude-comptes-20261002-100000.tar.gz"
  [IO.File]::WriteAllBytes($f1, (New-Object byte[] 2048))
  [IO.File]::WriteAllBytes($f2, (New-Object byte[] 10))
  [IO.File]::WriteAllText((Join-Path $webDl "autre.zip"), "x")
  (Get-Item $f1).LastWriteTime = [datetime]"2026-10-01 10:00"
  (Get-Item $f2).LastWriteTime = [datetime]"2026-10-02 10:00"
  Add-BackupMark $f1
  Add-BackupMark $f2
  $b = Get-WebBackups
  Assert-Equal "claude-comptes-20261002-100000.tar.gz claude-comptes-20261001-100000.zip" (@($b.items | ForEach-Object { $_.name }) -join " ") "web listes : sauvegardes, la plus recente en haut"
  Assert-Equal "2026-10-02T10:00" @($b.items)[0].when "web listes : date de la sauvegarde, format ISO pour la page"
  Assert-Equal $webDl $b.dir "web listes : dossier des sauvegardes"
  Assert-Equal $f1 (Find-WebBackup "claude-comptes-20261001-100000.zip") "web listes : sauvegarde trouvee par son nom"
  foreach ($bad in @("autre.zip", "..\claude-comptes-20261001-100000.zip", "CLAUDE-COMPTES-20261001-100000.ZIP", "")) {
    $err = ""
    try { $null = Find-WebBackup $bad } catch { $err = $_.Exception.Message }
    Assert-Equal (Get-ClmText "server.backupNotFound" @($bad)) $err ("web listes : nom refuse [" + $bad + "]")
  }
} finally {
  foreach ($n in $webMocked) { Set-Item ("function:" + $n) $webKept[$n] }
  $script:MenuState = $webSaved.Menu
  $script:DriveJob = $webSaved.Drive
  $script:Ink = $webSaved.Ink
  $script:InkTo = $webSaved.InkTo
  $script:ClmCheck = $webSaved.Check
  $script:Startup = $webSaved.Startup
}
