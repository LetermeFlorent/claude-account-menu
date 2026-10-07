function Get-OutcomeFor {
  param([string[]]$Lines, [int]$Code = 0, [string]$Killed = "")
  $st = New-UpdateState
  foreach ($l in $Lines) { Add-UpdateLine $st $l }
  return Get-UpdateOutcome $st $Code $Killed
}

$native = @("Current version: 2.1.268", "Checking for updates to latest version...", "",
  "Warning: Native installation exists but C:\x\.local\bin is not in your PATH", "Updating to 2.1.292...",
  "Successfully updated from 2.1.268 to version 2.1.292")
$o = Get-OutcomeFor $native
Assert-Equal "updated" $o.Kind "update native, type"
Assert-Equal "Claude Code mis a jour, 2.1.268 -> 2.1.292" $o.Text "update native, texte"

$o = Get-OutcomeFor @("Current version: 2.1.292", "Checking for updates to latest version...", "Claude Code is up to date (2.1.292)")
Assert-Equal "ok" $o.Kind "a jour, type"
Assert-Equal "Claude Code a jour (2.1.292)" $o.Text "a jour, texte"

$o = Get-OutcomeFor @("Current version: 2.1.290", "Claude is up to date!")
Assert-Equal "Claude Code a jour (2.1.290)" $o.Text "a jour sans version, reprend la version courante"

$o = Get-OutcomeFor @("Current version: 2.1.0", "New version available: 2.1.5 (current: 2.1.0)", "Installing update...", "Successfully updated from 2.1.0 to version 2.1.5")
Assert-Equal "Claude Code mis a jour, 2.1.0 -> 2.1.5" $o.Text "update npm"

$o = Get-OutcomeFor @("Current version: 2.1.0", "Claude is managed by Homebrew.", "Update available: 2.1.5")
Assert-Equal "manual" $o.Kind "gestionnaire de paquets, type"
Assert-Equal "Claude Code 2.1.5 disponible, a installer avec Homebrew" $o.Text "gestionnaire de paquets, texte"

$o = Get-OutcomeFor @("Current version: 2.1.0", "Another process is currently running an update") 1
Assert-Equal "mise a jour de Claude Code deja en cours ailleurs" $o.Text "update deja en cours"

$o = Get-OutcomeFor @("Current version: 2.1.0", "Error: failed to fetch latest version") 1
Assert-Equal "failed" $o.Kind "erreur, type"
Assert-Equal "echec de la mise a jour : Error: failed to fetch latest version" $o.Text "erreur, texte"

$o = Get-OutcomeFor @("Current version: 2.1.0", "Checking for updates to latest version...") 3
Assert-Equal "echec de claude update (code 3)" $o.Text "code de sortie seul"

$o = Get-OutcomeFor @("Current version: 2.1.0") 0 "check"
Assert-Equal "mise a jour de Claude Code : verification impossible" $o.Text "arret apres 20 s"
$o = Get-OutcomeFor @("Updating to 2.1.292...") 0 "stall"
Assert-Equal "mise a jour de Claude Code abandonnee, telechargement bloque" $o.Text "arret, telechargement fige"

$st = New-UpdateState
Add-UpdateLine $st "Updating to 2.2.0-beta.1..."
Assert-Equal "native" $st.Mode "mode natif"
Assert-Equal "2.2.0-beta.1" $st.Target "version avec suffixe"
Assert-Equal "Updating to 2.2.0-beta.1..." $st.Last "derniere ligne non vide"
Add-UpdateLine $st "   "
Assert-Equal "Updating to 2.2.0-beta.1..." $st.Last "ligne vide ignoree"

Assert-Equal 50 (Get-DownloadPercent 127429200 254858400) "pourcentage"
Assert-Equal 100 (Get-DownloadPercent 300000000 254858400) "pourcentage borne"
Assert-Equal -1 (Get-DownloadPercent 1000 0) "taille inconnue"
Assert-Equal "121 / 243 Mo" (Format-DownloadDetail 127429200 254858400) "detail avec taille"
Assert-Equal "121 Mo" (Format-DownloadDetail 127429200 0) "detail sans taille"

Assert-Equal "win32-x64" (Get-ManifestPlatform "Windows" "amd64") "plateforme Windows x64"
Assert-Equal "win32-arm64" (Get-ManifestPlatform "Windows" "ARM64") "plateforme Windows arm64"
Assert-Equal "darwin-arm64" (Get-ManifestPlatform "MacOS" "arm64") "plateforme macOS arm64"
Assert-Equal "darwin-x64" (Get-ManifestPlatform "MacOS" "x64") "plateforme macOS x64"
Assert-Equal "linux-arm64" (Get-ManifestPlatform "Linux" "aarch64") "plateforme Linux arm64"
Assert-Equal "linux-x64-musl" (Get-ManifestPlatform "Linux" "x64" $true) "plateforme Linux musl"
$manifest = '{"version":"2.1.292","platforms":{"win32-x64":{"binary":"claude.exe","size":254858400},"linux-x64":{"binary":"claude","size":251456696}}}' | ConvertFrom-Json
Assert-Equal 254858400 (Get-ManifestEntry $manifest "win32-x64").Size "manifest, taille"
Assert-Equal "claude" (Get-ManifestEntry $manifest "linux-x64").Binary "manifest, nom du binaire"
Assert-Null (Get-ManifestEntry $manifest "darwin-arm64") "manifest, plateforme absente"
Assert-Null (Get-ManifestEntry $null "win32-x64") "manifest injoignable"

Assert-True (Test-StagingDirName "2.1.292.16536.1791367380700" "2.1.292" 16536) "staging, dossier du process"
Assert-True (Test-StagingDirName "2.1.292.16536.1791367380700.3b581f1c" "2.1.292" 16536) "staging, suffixe hexa"
Assert-True (Test-StagingDirName "2.1.292" "2.1.292" 16536) "staging, nom court"
Assert-True (-not (Test-StagingDirName "2.1.292.999.1791367380700" "2.1.292" 16536)) "staging, autre process"
Assert-True (-not (Test-StagingDirName "2.1.2920.16536.1" "2.1.292" 16536)) "staging, autre version"

Assert-Equal "" (Get-WatchAction 19.9 $false $false $false 0) "attente de la verification"
Assert-Equal "check" (Get-WatchAction 20 $false $false $false 0) "verification trop longue"
Assert-Equal "" (Get-WatchAction 300 $true $false $false 300) "staging jamais vu, pas d'arret"
Assert-Equal "" (Get-WatchAction 300 $true $true $false 89) "taille immobile depuis 89 s"
Assert-Equal "stall" (Get-WatchAction 300 $true $true $false 90) "taille immobile depuis 90 s"
Assert-Equal "" (Get-WatchAction 300 $true $true $true 500) "fichier complet ou disparu, pas d'arret"

$script:ClaudeExe = "C:\Users\u\.local\bin\claude.exe"
$accs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "pro"; Dir = ".claude-compte2" })
$groups = @(Get-UpdateGroups $accs)
Assert-Equal 1 $groups.Count "un groupe par executable"
Assert-Equal 2 @($groups[0].Accounts).Count "deux comptes dans le groupe"
Assert-Equal "compte1" $groups[0].Accounts[0].Label "premier compte du groupe"
Assert-Equal "  compte1, pro : Claude Code a jour (2.1.292)" (Format-UpdateMessage $groups[0].Accounts "Claude Code a jour (2.1.292)") "message sous le menu"
