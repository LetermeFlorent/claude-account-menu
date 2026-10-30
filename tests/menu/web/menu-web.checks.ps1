. (Join-Path $PSScriptRoot "menu-web-fakes.ps1")

try {
  $script:Startup = $null
  $script:DriveJob = $null
  $script:MenuState = New-MwState
  $script:MwKeys = New-Object 'System.Collections.Generic.Queue[object]'
  function Read-UiInput { if ($script:MwKeys.Count -gt 0) { return $script:MwKeys.Dequeue() }; return $null }
  $script:MwUrls = New-Object 'System.Collections.Generic.List[string]'
  function Open-Browser { param([string]$Url) $script:MwUrls.Add($Url) }

  Assert-Equal "web" (Get-MenuAction (New-KeyInfo "w") 3).Name "menu web : touche w"
  Assert-True ($script:MenuFooter -join " ").Contains("w " + (Get-ClmText "ui.footer.web")) "menu web : touche w au pied du menu"
  $segs = @(foreach ($fr in (Get-FooterRows $script:MenuFooter 100 $script:MenuFooterAccent)) { $fr })
  $accent = ($script:Levels["5h"][0] -join ",")
  Assert-Equal ($accent + "|" + $accent) ((@($segs | Where-Object { $_[3] -eq "w" }) | ForEach-Object { $_[1] -join "," }) -join "|") "menu web : touche w et son texte en couleur"
  Assert-Equal (($script:Ink.Text -join ",") + "|" + ($script:Ink.Dim -join ",")) ((@($segs | Where-Object { $_[3] -eq "q" }) | ForEach-Object { $_[1] -join "," }) -join "|") "menu web : autres touches inchangees"
  Assert-True (@(foreach ($fr in (Get-FooterRows $script:MenuFooter 100)) { $fr | Where-Object { $_[3] -eq "w" -and ($_[1] -join ",") -eq $accent } }).Count -eq 0) "pied de page sans accent : couleurs habituelles"
  $su = New-Startup @("claude")
  $su.Steps[0].State = "run"
  Assert-Equal "web" (Get-StartupGate $su @{ Name = "web" } $script:MenuState).Name "menu web : page ouverte pendant le demarrage"

  $script:MwPolls = New-Object 'System.Collections.Generic.List[string]'
  $script:UiPoll = { $script:MwPolls.Add([string]$script:WebOpen) }
  $null = Read-UiKey
  Receive-UiKeys
  $null = Read-MenuAction $script:MenuState
  Assert-Equal "False False True" ($script:MwPolls -join " ") "menu web : requetes lues avec les touches, menu libre seulement dans la boucle"
  Assert-True (-not $script:WebOpen) "menu web : menu marque occupe hors de la lecture"
  $script:UiPoll = $null

  Open-MenuWeb $script:MenuState
  $url = $script:MwUrls[0]
  Assert-True ($url -match '^http://127\.0\.0\.1:[0-9]+/boot\?c=[0-9a-f]{32}$') "menu web : adresse locale avec un code d'entree"
  Assert-Equal ($url + " |   " + (Get-ClmText "web.menu.url" $url)) ($script:MwUrls[0] + " | " + $script:MenuState.Msg[0]) "menu web : navigateur ouvert, adresse dans le menu"
  Assert-True ($null -ne $script:UiPoll) "menu web : requetes suivies"
  Open-MenuWeb $script:MenuState
  Assert-True ($script:MwUrls.Count -eq 2 -and $script:MwUrls[1] -ne $url -and $script:MwUrls[1].StartsWith($url.Substring(0, $url.IndexOf("?")))) "menu web : seconde touche w, meme page avec un nouveau code"

  $c = Send-MwAsk "GET /api/state"
  $a = Wait-MwAction
  $reply = Read-MwReply $c
  Assert-True ($reply -match '"open":\s*true' -and $reply -match '"label":\s*"perso"') "menu web : etat servi depuis la boucle, menu libre"
  $c = Send-MwAsk "GET /api/state"
  $end = [DateTime]::UtcNow.AddMilliseconds(500)
  while ([DateTime]::UtcNow -lt $end -and $c.Available -eq 0) { $null = Read-UiKey; Start-Sleep -Milliseconds 10 }
  Assert-True ((Read-MwReply $c) -match '"open":\s*false') "menu web : etat servi pendant une page du terminal, menu occupe"

  $c = Send-MwAsk "POST /api/action" '{"do":"add","name":""}'
  $a = Wait-MwAction
  $reply = Read-MwReply $c
  Assert-Equal "add|" ($a.Name + "|" + $a.Arg) "menu web : ajout demande par la page, passe au terminal"
  Assert-True ($reply -match '^HTTP/1\.1 200 ' -and $reply -match '"ok":\s*true') "menu web : page prevenue avant l'ajout"
  Assert-Equal ("  " + (Get-ClmText "server.addStarted")) $script:MenuState.Msg[0] "menu web : message dans le terminal"

  $c = Send-MwAsk "POST /api/action" '{"do":"rename","acc":".claude","name":"x"}'
  $script:MwKeys.Enqueue((New-KeyInfo "m"))
  $a = Wait-MwAction
  Assert-Equal "refresh 1" ($a.Name + " " + $script:Web.Actions.Count) "menu web : touche du clavier d'abord, action gardee"
  $script:MwKeys.Enqueue((New-KeyInfo "q"))
  $a = Wait-MwAction
  Assert-Equal "quit" $a.Name "menu web : touche suivante lue"

  $script:WebReopen = $false
  Close-MenuWeb
  Assert-True ($null -eq $script:Web -and $null -eq $script:UiPoll -and $script:WebReopen) "menu web : serveur arrete, page a rouvrir apres un redemarrage"
  Assert-True ((Read-MwReply $c) -match '^HTTP/1\.1 409 ') "menu web : action en attente refusee a l'arret"
  Assert-Equal "--no-update --web" ((Get-WebRestartArgs @("--no-update")) -join " ") "menu web : redemarrage avec la page"
  Assert-Equal "--web --updated" ((Get-WebRestartArgs @("--web", "--updated")) -join " ") "menu web : drapeau jamais double"
  Assert-Equal "--web" ((Get-WebRestartArgs @()) -join " ") "menu web : redemarrage sans argument"
  $script:WebReopen = $false
  Assert-Equal "-2" ((Get-WebRestartArgs @("-2")) -join " ") "menu web : page fermee, arguments gardes"
  Close-MenuWeb
  Assert-True (-not $script:WebReopen) "menu web : sans page ouverte, rien a rouvrir"

  function Start-WebServer { param($Views) throw "port pris" }
  $script:MwUrls.Clear()
  Open-MenuWeb $script:MenuState
  Assert-Equal "  page web impossible : port pris" $script:MenuState.Msg[0] "menu web : echec du serveur dans le menu"
  Assert-True ((@($script:MenuState.Msg[1]) -join ",") -eq (@($script:Ink.Alert) -join ",") -and $script:MwUrls.Count -eq 0 -and $null -eq $script:UiPoll) "menu web : echec sans navigateur ni suivi"
  Set-MwReal "Start-WebServer"

  function Enter-UiScreen {}
  function Open-MenuSession { param($Update, $SelfUpdate) $script:MenuState = New-MwState }
  $script:MwOpened = 0
  function Open-MenuWeb { param($State) $script:MwOpened++; $script:UiPoll = { } }
  function Invoke-MenuLoop { throw "panne" }
  $err = ""
  try { $null = Invoke-AccountMenu $false $false $true } catch { $err = $_.Exception.Message }
  Assert-True ($err -eq "panne" -and $script:MwOpened -eq 1 -and $null -eq $script:UiPoll) "menu web : clm --web ouvre la page, arret garanti sur erreur"
  function Invoke-MenuLoop { return "compte" }
  Assert-Equal "compte 1" ("" + (Invoke-AccountMenu $false) + " " + $script:MwOpened) "menu web : sans --web, page fermee"

  Set-MwReal "Invoke-MenuLoop"
  $script:MwActs = New-Object 'System.Collections.Generic.Queue[object]'
  foreach ($x in @(@{ Name = "web" }, @{ Name = "add"; Arg = "neuf" }, @{ Name = "drivelogin" }, @{ Name = "quit" })) { $script:MwActs.Enqueue($x) }
  function Read-MenuAction { param($State) return $script:MwActs.Dequeue() }
  $script:MwCmds = New-Object 'System.Collections.Generic.List[string]'
  function Invoke-MenuCommand { param([string]$Name, $Arg = $null) $script:MwCmds.Add($Name + "|" + $Arg) }
  function Close-AccountMenu { param($Idx) return "ferme" }
  function Step-MenuFrame { return $false }
  $script:MwOpened = 0
  Assert-Equal "ferme 1 add|neuf drivelogin|" ("" + (Invoke-MenuLoop) + " " + $script:MwOpened + " " + ($script:MwCmds -join " ")) "menu web : boucle, touche w et suites des actions de la page"
} finally { Restore-MwFakes }
