. (Join-Path $PSScriptRoot "fake-drive.ps1")

function Start-GuardPc {
  param([string]$Name, [string[]]$Dirs = @(".claude"))
  Use-Pc $Name
  Save-Registry @($Dirs | ForEach-Object { [PSCustomObject]@{ Label = $_.TrimStart("."); Dir = $_ } })
}

function New-GuardLink {
  param([string]$Link, [string]$Target)
  $kind = "SymbolicLink"
  if ($script:OsName -eq "Windows") { $kind = "Junction" }
  New-Item -ItemType $kind -Path $Link -Value $Target | Out-Null
}

Start-GuardPc "GA" @(".claude", ".claude-compte2")
Set-PcFile ".claude/settings.json" "a" 1700000000
Set-PcFile ".claude-compte2/notes.md" "n2" 1700000000
$null = Invoke-DriveSync
Use-Pc "GB"
$r = Invoke-DriveSync
Assert-True $r.Ok ("PC neuf : synchro " + $r.Error)
Assert-Equal "n2" (Get-PcText ".claude-compte2/notes.md") "compte d'un autre PC recu des la premiere synchro"
Use-Pc "GA"
Start-Sleep -Milliseconds 1100
Save-Registry @([PSCustomObject]@{ Label = "c1"; Dir = ".claude" })
$r = Invoke-DriveSync
Assert-Equal 0 $r.Deleted "compte retire de la liste : rien supprime du Drive"
Assert-True $script:Fake.ContainsKey(".claude-compte2/notes.md") "compte retire : fichiers gardes sur le Drive"
Assert-Equal "n2" (Get-PcText ".claude-compte2/notes.md") "compte retire : dossier garde sur ce PC"
Use-Pc "GB"
$null = Invoke-DriveSync
$null = Invoke-DriveSync
Assert-Equal "n2" (Get-PcText ".claude-compte2/notes.md") "compte retire sur un autre PC : dossier garde ici"
Assert-True $script:Fake.ContainsKey(".claude-compte2/notes.md") "compte retire sur un autre PC : Drive intact"

$script:Fake = New-PathMap
Start-GuardPc "RA"
Set-PcFile ".claude/settings.json" "s" 1700000000
$null = Invoke-DriveSync
$script:Fake = New-PathMap
$script:FakeRoot = "R2"
$r = Invoke-DriveSync
Assert-Equal 0 $r.Deleted "dossier Drive remplace : rien supprime ici"
Assert-Equal "s" (Get-PcText ".claude/settings.json") "dossier Drive remplace : fichier local garde"
Assert-True $script:Fake.ContainsKey(".claude/settings.json") "dossier Drive remplace : tout renvoye"
$script:FakeRoot = "R"

$script:Fake = New-PathMap
Start-GuardPc "KA"
Set-PcFile ".claude/settings.json" "v1" 1700000000
$null = Invoke-DriveSync
Start-GuardPc "KB"
$null = Invoke-DriveSync
Use-Pc "KA"
Set-PcFile ".claude/settings.json" "v2" 1700000100
$null = Invoke-DriveSync
Use-Pc "KB"
$script:OnMedia = { Set-PcFile ".claude/settings.json" "claude" 1700000200 }
try { $r = Invoke-DriveSync } finally { $script:OnMedia = $null }
Assert-Equal "claude" (Get-PcText ".claude/settings.json") "fichier ecrit pendant le telechargement : garde"
Assert-Equal 1 $r.Left "fichier ecrit pendant le telechargement : laisse pour la prochaine synchro"
$r = Invoke-DriveSync
Assert-Equal 1 $r.Conflicts "fichier ecrit pendant le telechargement : conflit a la synchro suivante"

$script:Fake = New-PathMap
Start-GuardPc "HA"
Set-PcFile ".claude/CLAUDE.md" "v1" 1700000000
$null = Invoke-DriveSync
Start-GuardPc "HB"
$null = Invoke-DriveSync
$shared = Join-Path $script:HomeDir "other-CLAUDE.md"
New-Item -ItemType HardLink -Path $shared -Value (Join-Path $script:HomeDir ".claude/CLAUDE.md") | Out-Null
Use-Pc "HA"
Set-PcFile ".claude/CLAUDE.md" "v2" 1700000100
$null = Invoke-DriveSync
Use-Pc "HB"
$null = Invoke-DriveSync
Assert-Equal "v2" ([IO.File]::ReadAllText($shared)) "fichier partage par lien physique : lien garde apres reception"

$script:Fake = New-PathMap
Start-GuardPc "JA"
Set-PcFile ".claude/commands/x.md" "cmd" 1700000000
$null = Invoke-DriveSync
Start-GuardPc "JB"
$dots = Join-Path $script:HomeDir "dotfiles"
New-Item -ItemType Directory -Path $dots | Out-Null
New-Item -ItemType Directory -Path (Join-Path $script:HomeDir ".claude") -Force | Out-Null
New-GuardLink (Join-Path $script:HomeDir ".claude/commands") $dots
$null = Invoke-DriveSync
$null = Invoke-DriveSync
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dots "x.md"))) "dossier lie : rien ecrit a travers le lien"
Assert-True $script:Fake.ContainsKey(".claude/commands/x.md") "dossier lie : fichiers du Drive gardes"
(Get-Item -LiteralPath (Join-Path $script:HomeDir ".claude/commands")).Delete()

if ($script:OsName -ne "Linux") {
  $script:Fake = New-PathMap
  Start-GuardPc "CA"
  Set-PcFile ".claude/note.md" "x" 1700000000
  $null = Invoke-DriveSync
  Start-GuardPc "CB"
  $null = Invoke-DriveSync
  Use-Pc "CA"
  $p = Join-Path $script:HomeDir ".claude"
  [IO.File]::Move((Join-Path $p "note.md"), (Join-Path $p "tmp.md"))
  [IO.File]::Move((Join-Path $p "tmp.md"), (Join-Path $p "Note.md"))
  foreach ($pc in "CA", "CB", "CA", "CB") { Use-Pc $pc; $null = Invoke-DriveSync }
  Use-Pc "CB"
  Assert-Equal "x" (Get-PcText ".claude/note.md") "renommage de casse : fichier jamais perdu sur l'autre PC"
  Use-Pc "CA"
  Assert-Equal "x" (Get-PcText ".claude/Note.md") "renommage de casse : fichier garde ici"
}

Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
