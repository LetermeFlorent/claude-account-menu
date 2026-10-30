function Get-HeaderText {
  param($Row)
  $t = ""
  foreach ($s in $Row) { $t += $s[0] }
  return $t
}

$installed = [PSCustomObject]@{ Sha = ("a" * 40); Time = [long]100; Number = 33 }
$newer = [PSCustomObject]@{ Sha = ("b" * 40); Time = [long]200; Number = 40 }

function New-FakeCheckLoader {
  param($Latest, [bool]$Done = $true)
  $q = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  if ($Done) { $q.Enqueue(@(0, $Latest, $null)) }
  return @{ Ps = $null; Ctl = @{ Done = $Done; Error = $null }; Queue = $q }
}

$off = New-ClmCheck 1000 $false $installed
Assert-Null $off.NextAt "lance hors de .local/bin, pas de verification"
Assert-True (-not (Step-ClmCheck $off 99999999)) "verification coupee, rien a faire"
Assert-Null $off.Loader "verification coupee, rien de lance"

$chk = New-ClmCheck 1000 $true $installed
Assert-Equal (1000 + $script:ClmCheckMs) $chk.NextAt "premiere verification dix minutes apres l'ouverture"
$keptLoader = (Get-Item "function:Start-UsageLoader").ScriptBlock
function Start-UsageLoader { param($Accounts, [string]$Source, [string]$Reader) return New-FakeCheckLoader $null $false }
try {
  Assert-True (-not (Step-ClmCheck $chk 2000)) "avant l'echeance, rien"
  Assert-Null $chk.Loader "avant l'echeance, rien de lance"
  $null = Step-ClmCheck $chk (1000 + $script:ClmCheckMs)
  Assert-True ($null -ne $chk.Loader) "a l'echeance, GitHub interroge en arriere-plan"
  Assert-True (-not (Step-ClmCheck $chk 700000)) "reponse pas encore arrivee"
} finally { Set-Item "function:Start-UsageLoader" $keptLoader }

$chk.Loader = New-FakeCheckLoader $installed
Assert-True (-not (Step-ClmCheck $chk 700000)) "meme version, pas de bouton"
Assert-Null $chk.Latest "meme version, rien en attente"
Assert-Equal (700000 + $script:ClmCheckMs) $chk.NextAt "verification suivante dix minutes plus tard"

$chk.Loader = New-FakeCheckLoader $null
Assert-True (-not (Step-ClmCheck $chk 800000)) "GitHub injoignable, pas de bouton"

$chk.Loader = New-FakeCheckLoader $newer
Assert-True (Step-ClmCheck $chk 900000) "nouvelle version, menu redessine"
Assert-Equal $newer.Sha $chk.Latest.Sha "nouvelle version gardee"
$chk.Loader = New-FakeCheckLoader $newer
Assert-True (-not (Step-ClmCheck $chk 1500000)) "nouvelle version deja signalee"

$script:ClmCheck = $null
Assert-True (-not (Test-ClmUpdateReady)) "pas de verification, pas de mise a jour"
$script:ClmCheck = $chk
Assert-True (Test-ClmUpdateReady) "mise a jour en attente"
Assert-Equal "selfupdate" (Get-MenuAction (New-KeyInfo "u") 3).Name "u met clm a jour"

$st = @{ Version = "clm v33" }
$wide = Get-MenuHeaderRow $st 80
Assert-True ((Get-HeaderText $wide) -match ("^  " + [regex]::Escape((Get-ClmText "menu.screen.title")) + "  clm v33  " + [regex]::Escape("[" + (Get-ClmText "menu.screen.update_available") + "]") + " +\d\d:\d\d$")) "bouton a cote de la version"
Assert-Equal "u" (Get-FooterKeyAt @(, $wide) 37 0) "clic sur le bouton, touche u"
Assert-Null (Get-FooterKeyAt @(, $wide) 25 0) "clic sur la version, rien"
Assert-True ((Get-HeaderText (Get-MenuHeaderRow $st 46)) -match ("^  " + [regex]::Escape((Get-ClmText "menu.screen.title")) + "  " + [regex]::Escape("[" + (Get-ClmText "menu.screen.update_available") + "]") + " +\d\d:\d\d$")) "fenetre etroite, bouton garde, version retiree"
foreach ($w in 30, 46, 53, 80) { Assert-True ((Get-HeaderText (Get-MenuHeaderRow $st $w)).Length -le $w - 2) ("en-tete avec bouton dans la largeur " + $w) }
$script:ClmCheck = $null
Assert-True ((Get-HeaderText (Get-MenuHeaderRow $st 80)) -notmatch [regex]::Escape((Get-ClmText "menu.screen.update_available"))) "pas de mise a jour, pas de bouton"
