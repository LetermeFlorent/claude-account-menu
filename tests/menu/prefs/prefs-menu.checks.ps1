. (Join-Path $PSScriptRoot "prefs-fakes.ps1")

try {
  $cat = New-PrefsFixture
  $cat.Waiting = [string[]]@("vieux", "mac")
  Assert-Equal (Get-ClmText "sync.prefs.sub.waiting" @("vieux, mac")) (Get-PrefsSub $cat) "sous-titre : PC pas a jour"
  $cat.Waiting = [string[]]@()
  Assert-Equal (Get-ClmText "sync.prefs.sub.perPc") (Get-PrefsSub $cat) "sous-titre : mode par PC pas encore actif"
  $cat.PerPc = $true
  Assert-Equal (Get-ClmText "sync.prefs.sub.checked") (Get-PrefsSub $cat) "sous-titre : mode par PC"
  $offAll = New-PrefsAll "skills" (Get-ClmText "sync.prefs.all.skills") @((New-PrefsItem @{ Kind = "skills"; Key = "a"; Label = "a"; Tag = ""; On = $true; Erasing = $false }), (New-PrefsItem @{ Kind = "skills"; Key = "b"; Label = "b"; Tag = ""; On = $false; Erasing = $false }), (New-PrefsItem @{ Kind = "skills"; Key = "c"; Label = "c"; Tag = ""; On = $true; Erasing = $false }))
  Assert-Equal ((Get-PrefsOffWarn "skills") + "|  " + (Get-ClmText "sync.prefs.manyOff" @(2))) ((Get-PrefsOffLines $offAll) -join "|") "tout decocher : seules les cases cochees comptent"
  Assert-True ((Get-PrefsOffLines (New-PrefsItem @{ Kind = "globals"; Key = "g"; Label = "g"; Tag = ""; On = $true; Erasing = $false }) "B")[0].Contains("B")) "decocher pour un autre PC : son nom dit"

} finally {
  Restore-PrefsFakes
}
