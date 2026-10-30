$cwBytes = $null
if (Test-Path -LiteralPath $script:UsageCachePath) { $cwBytes = [IO.File]::ReadAllBytes($script:UsageCachePath) }
$cwReader = (Get-Item "function:Read-SharedText").ScriptBlock
$cwUsage = [PSCustomObject]@{ Pct5 = 4; Reset5 = $null; Pct7 = 5; Reset7 = $null }

try {
  New-Item -ItemType Directory -Force -Path (Split-Path $script:UsageCachePath) | Out-Null
  [IO.File]::WriteAllText($script:UsageCachePath, "{ oups", (New-Object Text.UTF8Encoding($false)))
  Save-UsageEntry "neuf" $cwUsage
  Assert-Equal 4 (Read-UsageCache)["neuf"].Pct5 "cache illisible : remplace par l'entree ecrite"

  Save-UsageEntry "garde" $cwUsage
  function Read-SharedText { param([string]$Path) throw (New-Object IO.IOException "fichier occupe") }
  try { $cwOk = Update-UsageCache { param($map) $map["perdu"] = 1 } } finally { Set-Item "function:Read-SharedText" $cwReader }
  Assert-Equal "False" ("" + $cwOk) "cache occupe a la relecture : ecriture refusee"
  $cwMap = Read-UsageCache
  Assert-True ($cwMap.ContainsKey("garde") -and $cwMap.ContainsKey("neuf")) "cache occupe a la relecture : autres comptes gardes"
  Assert-True (-not $cwMap.ContainsKey("perdu")) "cache occupe a la relecture : rien ecrit"

  $cwOk = Update-UsageCache { param($map) $map["ajout"] = 1 }
  Assert-Equal "True" ("" + $cwOk) "cache ecrit : succes rendu"
  Assert-Equal 0 @(Save-UsageEntry "muet" $cwUsage).Count "enregistrement d'un compte : rien en sortie"
  Assert-Equal 0 @(Rename-UsageEntry "muet" "muet2").Count "renommage d'un compte : rien en sortie"
} finally {
  Set-Item "function:Read-SharedText" $cwReader
  if ($null -ne $cwBytes) { [IO.File]::WriteAllBytes($script:UsageCachePath, $cwBytes) } else { Remove-Item -LiteralPath $script:UsageCachePath -Force -ErrorAction SilentlyContinue }
}
