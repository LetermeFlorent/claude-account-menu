. Import-ClmModule claude-ui-wt-theme

$script:WtCase = 0
$stable = "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$preview = "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
$idA = "{11111111-1111-1111-1111-111111111111}"
$idB = "{22222222-2222-2222-2222-222222222222}"

function Get-WtCaseResult {
  param([string]$Json, [string]$RelPath = $stable, [string]$ProfileId = "", [string]$Session = "x")
  $script:WtCase++
  $root = "wtcase" + $script:WtCase
  if ($Json -ne "") { [void](New-SandboxFile (Join-Path $root $RelPath) $Json) }
  $vars = @{ WT_SESSION = $Session; LOCALAPPDATA = (Join-Path $script:Sandbox $root); WT_PROFILE_ID = $ProfileId }
  return (Get-WtTheme -Vars $vars)
}

$light = '{ "defaultProfile": "' + $idA + '", "profiles": { "list": [ { "guid": "' + $idA + '", "colorScheme": "One Half Light" } ] } }'
Assert-Equal "" (Get-WtCaseResult $light $stable "" "") "Windows Terminal : sans WT_SESSION on ne lit rien"

$campbell = '{ "defaultProfile": "' + $idA + '", "profiles": { "list": [ { "guid": "' + $idA + '" } ] } }'
Assert-Equal "dark" (Get-WtCaseResult $campbell) "Windows Terminal : schema Campbell par defaut sombre"
Assert-Equal "light" (Get-WtCaseResult $light) "Windows Terminal : schema clair du profil"

$user = '{ "defaultProfile": "' + $idA + '", "profiles": { "list": [ { "guid": "' + $idA + '", "colorScheme": "Mon Schema" } ] }, "schemes": [ { "name": "Mon Schema", "background": "#F0F0F0" } ] }'
Assert-Equal "light" (Get-WtCaseResult $user) "Windows Terminal : schema utilisateur clair"

$override = '{ "defaultProfile": "' + $idA + '", "profiles": { "list": [ { "guid": "' + $idA + '", "colorScheme": "Campbell", "background": "#FDF6E3" } ] } }'
Assert-Equal "light" (Get-WtCaseResult $override) "Windows Terminal : fond du profil prioritaire sur le schema"

$defBg = '{ "defaultProfile": "' + $idA + '", "profiles": { "defaults": { "background": "#fff" }, "list": [ { "guid": "' + $idA + '" } ] } }'
Assert-Equal "light" (Get-WtCaseResult $defBg) "Windows Terminal : fond des defaults utilise"

$two = '{ "defaultProfile": "' + $idA + '", "profiles": { "list": [ { "guid": "' + $idA + '", "colorScheme": "Campbell" }, { "guid": "' + $idB + '", "colorScheme": "Solarized Light" } ] } }'
Assert-Equal "light" (Get-WtCaseResult $two $stable $idB.ToUpper()) "Windows Terminal : WT_PROFILE_ID choisit le bon profil"
Assert-Equal "dark" (Get-WtCaseResult $two) "Windows Terminal : profil par defaut sans WT_PROFILE_ID"

$defScheme = '{ "defaultProfile": "' + $idA + '", "profiles": { "defaults": { "colorScheme": "One Half Light" }, "list": [ { "guid": "' + $idA + '" } ] } }'
Assert-Equal "light" (Get-WtCaseResult $defScheme) "Windows Terminal : schema des defaults utilise"

$obj = '{ "defaultProfile": "' + $idA + '", "profiles": { "list": [ { "guid": "' + $idA + '", "colorScheme": { "dark": "Campbell", "light": "One Half Light" } } ] } }'
Assert-Equal "" (Get-WtCaseResult $obj) "Windows Terminal : schema en objet inconnu"

$unknown = '{ "defaultProfile": "' + $idA + '", "profiles": { "list": [ { "guid": "' + $idA + '", "colorScheme": "Inconnu" } ] } }'
Assert-Equal "" (Get-WtCaseResult $unknown) "Windows Terminal : nom de schema inconnu"

$commented = @"
// header comment
{
  /* block
     comment */
  "defaultProfile": "$idA", // trailing
  "url": "https://example.com/a//b",
  "profiles": {
    "list": [
      { "guid": "$idA", "colorScheme": "One Half Light", },
    ],
  },
}
"@
Assert-Equal "light" (Get-WtCaseResult $commented) "Windows Terminal : commentaires et virgules finales acceptes"

$old = '{ "defaultProfile": "' + $idA + '", "profiles": [ { "guid": "' + $idA + '", "colorScheme": "Solarized Light" } ] }'
Assert-Equal "light" (Get-WtCaseResult $old) "Windows Terminal : ancien format de profils en tableau"

Assert-Equal "" (Get-WtCaseResult "{ this is not json") "Windows Terminal : fichier casse sans erreur"
Assert-Equal "" (Get-WtCaseResult "") "Windows Terminal : aucun fichier de reglages"
Assert-Equal "light" (Get-WtCaseResult $light $preview) "Windows Terminal : chemin de la version Preview"

$hex = ConvertFrom-WtHexColor "#0C0C0C"
Assert-Equal "12,12,12" ($hex -join ",") "Windows Terminal : lecture de #0C0C0C"
Assert-Equal "255,255,255" ((ConvertFrom-WtHexColor "#fff") -join ",") "Windows Terminal : lecture de #fff"
Assert-Null (ConvertFrom-WtHexColor "nope") "Windows Terminal : couleur mal formee"
