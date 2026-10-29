$redrawMocked = @("Write-Frame", "Read-UiKey", "Update-UiTick")
$redrawKept = @{}
foreach ($n in $redrawMocked) { $redrawKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }

function Write-Frame { param($Rows, [int]$Max, $Fades = $null) $script:RedrawCount++ }
function Update-UiTick { param([double]$Now, [bool]$Busy) $script:RedrawTicks++; return ($script:RedrawTicks -eq $script:RedrawResizeAt) }
function Read-UiKey {
  $script:RedrawReads++
  if ($script:RedrawReads -lt $script:RedrawKeyAt) { return $null }
  return New-Object System.ConsoleKeyInfo ([char]"x"), ([ConsoleKey]::X), $false, $false, $false
}

function Invoke-RedrawPage {
  param([scriptblock]$Build, [int]$Ticks, [int]$ResizeAt = 0)
  $script:RedrawCount = 0; $script:RedrawTicks = 0; $script:RedrawReads = 0
  $script:RedrawKeyAt = $Ticks; $script:RedrawResizeAt = $ResizeAt
  $null = Read-PageKey $Build
  return $script:RedrawCount
}

try {
  $script:ScreenFade = $null; $script:FadeArmed = $false; $script:LastRows = $null; $script:UiProgress = $null
  $still = { Get-PageRows "Titre" (Get-ListRows @("a", "b") 0) @("Echap", "annuler") }
  Assert-Equal 1 (Invoke-RedrawPage $still 6) "page fixe : un seul dessin pour six tours"
  Assert-Equal 0 (Invoke-RedrawPage $still 6) "page fixe deja a l'ecran : aucun dessin"
  Assert-Equal 1 (Invoke-RedrawPage $still 6 3) "console redimensionnee : un dessin de plus"
  $script:LastRows = $null
  Assert-Equal 1 (Invoke-RedrawPage $still 6) "ecran efface : la page revient"
  $moving = { Get-PageRows "Titre" (Get-ListRows @(("tour " + [math]::Min($script:RedrawTicks, 3)), "b") 0) @() }
  Assert-Equal 3 (Invoke-RedrawPage $moving 6) "contenu change : un dessin par changement"
  $null = Invoke-RedrawPage $still 1
  $script:LastRows = @()
  Assert-Equal 1 (Invoke-RedrawPage $still 6) "autre ecran dessine entre deux : la page revient"
  $script:ScreenFade = New-Tween 0 1 60000 (Get-NowMs)
  Assert-Equal 6 (Invoke-RedrawPage $still 6) "fondu d'entree : chaque tour dessine"
  $script:ScreenFade = $null
  Assert-Equal 1 (Invoke-RedrawPage $still 6) "fondu d'entree fini : la page pleine dessinee une fois"
  $script:WorkPage = @{ Title = "Attente"; Text = "travail..." }
  $script:RedrawCount = 0; $script:LastRows = $null
  for ($i = 0; $i -lt 5; $i++) { Show-WorkPage }
  Assert-Equal 1 $script:RedrawCount "page d'attente fixe : un seul dessin"
} finally {
  foreach ($n in $redrawKept.Keys) { Set-Item -Path ("function:" + $n) -Value $redrawKept[$n] }
  $script:WorkPage = $null; $script:LastRows = $null; $script:ScreenFade = $null
}
