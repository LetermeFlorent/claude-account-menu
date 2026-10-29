. (Join-Path $bin "claude-color.ps1")
. (Join-Path $bin "claude-web-page.ps1")

Assert-Equal "21" ([math]::Round((Get-ColorContrast "#ffffff" "#000000"), 2)) "couleurs : contraste noir sur blanc"
Assert-Equal "0" (Get-ColorContrast "bleu" "#000000") "couleurs : couleur illisible sans erreur"
Assert-Equal "#0078d7" (ConvertFrom-AccentDword 0xffd77800L) "accent Windows : ABGR vers #rrggbb"
Assert-Equal "#0078d7" (ConvertFrom-AccentDword ([int32]-2656256)) "accent Windows : DWORD signe du registre"
Assert-Equal "" (ConvertFrom-AccentDword $null) "accent Windows : valeur absente"
Assert-Equal "" (Read-WindowsAccent "Linux") "accent : rien hors de Windows"
Assert-Equal "" (Read-WindowsAccent "MacOS") "accent : rien sur macOS"

$coKept = (Get-Item function:Read-WindowsAccentDword).ScriptBlock
try {
  function Read-WindowsAccentDword { throw "registre illisible" }
  Assert-Equal "" (Read-WindowsAccent "Windows") "accent Windows : lecture en echec sans erreur"
  function Read-WindowsAccentDword { return 0xff0000ffL }
  Assert-Equal "#ff0000" (Read-WindowsAccent "Windows") "accent Windows : couleur lue"
} finally { Set-Item function:Read-WindowsAccentDword $coKept }

$coLight = $script:WebTokens["light"]
$coDark = $script:WebTokens["dark"]
Assert-True ($null -ne $coLight -and $null -ne $coDark) "palette : deux themes dans tokens.css"
$coPair = Get-AccentPair "#0078D7" $coLight
Assert-Equal "#0078d7 #000000" ($coPair.fill + " " + $coPair.ink) "accent : bleu Windows garde en clair, texte noir car le blanc reste sous 4.5"
Assert-Null (Get-AccentPair "#0078d7" $coDark) "accent : bleu Windows trop sombre en theme sombre, accent de repli"
Assert-Null (Get-AccentPair "#ffeb3b" $coLight) "accent : jaune illisible sur fond clair refuse"
Assert-Null (Get-AccentPair "rose" $coLight) "accent : couleur illisible refusee"
foreach ($t in @("light", "dark")) {
  $set = $script:WebTokens[$t]
  Assert-True ($null -ne (Get-AccentPair $set["accent"] $set)) ("accent de repli " + $t + " : passe le niveau AA")
}

$coText = @("text", "muted", "ok", "warn", "alert")
$coBacks = @("bg", "surface", "hover", "selected")
$coFails = @()
foreach ($t in @("light", "dark")) {
  $set = $script:WebTokens[$t]
  foreach ($fg in $coText) { foreach ($b in $coBacks) { if ((Get-ColorContrast $set[$fg] $set[$b]) -lt 4.5) { $coFails += ($t + " " + $fg + "/" + $b) } } }
  foreach ($b in @("notice", "alert-soft")) { foreach ($fg in @("text", "alert")) { if ((Get-ColorContrast $set[$fg] $set[$b]) -lt 4.5) { $coFails += ($t + " " + $fg + "/" + $b) } } }
  if ((Get-ColorContrast $set["on-accent"] $set["accent"]) -lt 4.5) { $coFails += ($t + " on-accent/accent") }
  foreach ($ui in @("border", "accent", "focus")) { foreach ($b in @("bg", "surface")) { if ((Get-ColorContrast $set[$ui] $set[$b]) -lt 3) { $coFails += ($t + " " + $ui + "/" + $b) } } }
  foreach ($fill in @("accent", "warn", "alert")) { if ((Get-ColorContrast $set[$fill] $set["track"]) -lt 3) { $coFails += ($t + " " + $fill + "/track") } }
}
Assert-Equal "" ($coFails -join ", ") "palette : contrastes AA dans les deux themes"
