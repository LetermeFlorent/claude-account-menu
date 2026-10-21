$fh = Join-Path $script:Sandbox "pc-files"
foreach ($rel in @(".claude/settings.json", ".claude/cache/x.bin", ".claude/plugins/cache/p.js", ".claude/a.lock", ".claude/x.json.conflit-MAC", ".claude/.credentials.json", ".claude/settings.json.bak-sync", ".claude/w.json.ab12.tmp", ".claude/outils/chrome-bidi/profils/c/Cookies", ".claude-compte2/skills/s.md", ".claude-compte2/notes.md", ".claude-compte2/CLAUDE.md", ".claude/projects/C--x/a b.jsonl", ".claude/projects/C--x/memory/a b.md", ".claude.json", ".claude-accounts.json", ".autre/hors.md")) {
  $null = New-SandboxFile ("pc-files/" + $rel) ("contenu " + $rel)
}
$accs = @([PSCustomObject]@{ Label = "a"; Dir = ".claude" }, [PSCustomObject]@{ Label = "b"; Dir = ".claude-compte2" })
$roots = Get-SyncRoots $accs
Assert-True ($roots -contains ".claude-accounts.json" -and $roots -contains ".claude.json" -and $roots -contains ".claude-compte2") "racines : comptes, config et registre"
$patterns = Get-SyncPatterns $accs
$res = Get-LocalFiles $fh $roots $patterns (New-PathMap)
$keys = [string[]]@($res.Files.Keys); [Array]::Sort($keys, [StringComparer]::Ordinal)
Assert-Equal ".claude-accounts.json|.claude-compte2/notes.md|.claude.json|.claude/projects/C--x/memory/a b.md|.claude/settings.json" ($keys -join "|") "perimetre : exclusions et elements partages ecartes"
$e = $res.Files[".claude/settings.json"]
Assert-Equal (Get-FileMd5 (Join-Path $fh ".claude/settings.json")) $e.Md5 "empreinte MD5 calculee"
Assert-Equal 32 $e.Md5.Length "MD5 en hexadecimal"
Assert-Equal ([IO.FileInfo](Join-Path $fh ".claude/settings.json")).Length $e.Size "taille lue"
$md5 = [Security.Cryptography.MD5]::Create()
$hex = -join ($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes("contenu .claude/settings.json")) | ForEach-Object { $_.ToString("x2") })
Assert-Equal $hex $e.Md5 "MD5 identique au calcul de Drive"

$n = $res.Files[".claude-compte2/notes.md"]
$base = New-PathMap
$base[".claude-compte2/notes.md"] = @{ Md5 = "cafe"; M = $n.M; Size = $n.Size; Id = "i" }
$base[".claude/settings.json"] = @{ Md5 = "cafe"; M = $e.M; Size = $e.Size; Id = "i" }
$res2 = Get-LocalFiles $fh $roots $patterns $base
Assert-Equal "cafe" $res2.Files[".claude-compte2/notes.md"].Md5 "taille et date inchangees, MD5 repris de la base"
Assert-Equal $e.Md5 $res2.Files[".claude/settings.json"].Md5 "reglages d'un compte : MD5 toujours recalcule"
$base[".claude-compte2/notes.md"].M = $n.M - 5
Assert-Equal $n.Md5 (Get-LocalFiles $fh $roots $patterns $base).Files[".claude-compte2/notes.md"].Md5 "date changee, MD5 recalcule"

New-Item -ItemType Directory -Path (Join-Path $fh "cible") -Force | Out-Null
$null = New-SandboxFile "pc-files/cible/dedans.md" "x"
New-Item -ItemType (Get-DirLinkType) -Path (Join-Path $fh ".claude/lien") -Target (Join-Path $fh "cible") | Out-Null
$res3 = Get-LocalFiles $fh $roots $patterns (New-PathMap)
Assert-True (-not $res3.Files.ContainsKey(".claude/lien/dedans.md")) "jonction ou lien ignore"

if ($script:OsName -eq "Windows") {
  $fs = [IO.File]::Open((Join-Path $fh ".claude-compte2/notes.md"), "Open", "ReadWrite", "None")
  try { $res4 = Get-LocalFiles $fh $roots $patterns (New-PathMap) } finally { $fs.Dispose() }
  Assert-True (-not $res4.Files.ContainsKey(".claude-compte2/notes.md")) "fichier verrouille absent de la liste"
  Assert-True ($res4.Skipped -contains ".claude-compte2/notes.md") "fichier verrouille marque illisible"
}

$res5 = Get-LocalFiles $fh $roots $patterns (New-PathMap) @{ Stop = $true }
Assert-True $res5.Stopped "arret demande : analyse interrompue"
Assert-True (-not $res5.Files.ContainsKey(".claude/settings.json")) "arret demande : dossiers non parcourus"
Assert-Equal '"ab\n"' (ConvertTo-JsonString "ab`n") "retour a la ligne final echappe"
Assert-Equal '"a\"b\\c"' (ConvertTo-JsonString 'a"b\c') "guillemet et barre oblique inverse echappes"

$st = Read-DriveState
Assert-Equal 0 $st.Files.Count "etat absent, base vide"
$st.Files[".claude/A.md"] = @{ Md5 = "m1"; M = 5; Size = 3; Id = "i1" }
$st.Files[".claude/a.md"] = @{ Md5 = "m2"; M = 6; Size = 4; Id = "i2" }
$st.Files['.claude/q"x\y.md'] = @{ Md5 = "m3"; M = 7; Size = 5; Id = "i3" }
$st.At = 77
Save-DriveState $st
$st2 = Read-DriveState
Assert-Equal 3 $st2.Files.Count "etat relu, casse distinguee"
Assert-Equal "i2" $st2.Files[".claude/a.md"].Id "id relu"
Assert-Equal "i3" $st2.Files['.claude/q"x\y.md'].Id "chemin avec guillemet et barre oblique inverse relu"
Assert-Equal 6 $st2.Files[".claude/a.md"].M "date relue"
Assert-Equal 77 $st2.At "date de synchro relue"
$escaped = [IO.File]::ReadAllText($script:DriveStatePath)
Assert-True (-not (Read-DriveStateRows @{ At = [long]0; Root = ""; Files = (New-PathMap) } $escaped)) "etat : chemin echappe, lecteur complet"
$st2.Files.Remove('.claude/q"x\y.md')
$st2.Root = "R"
Save-DriveState $st2
$plain = [IO.File]::ReadAllText($script:DriveStatePath)
$fast = @{ At = [long]0; Root = ""; Files = (New-PathMap) }
Assert-True (Read-DriveStateRows $fast $plain) "etat : lecture rapide du format ecrit"
Assert-Equal "R|77|2|m1|5|3|i1" ($fast.Root + "|" + $fast.At + "|" + $fast.Files.Count + "|" + $fast.Files[".claude/A.md"].Md5 + "|" + $fast.Files[".claude/A.md"].M + "|" + $fast.Files[".claude/A.md"].Size + "|" + $fast.Files[".claude/A.md"].Id) "etat : lecture rapide complete"
[IO.File]::WriteAllText($script:DriveStatePath, $plain.Replace("`n", "`r`n"))
$crlf = Read-DriveState
Assert-Equal "R|77|i2" ($crlf.Root + "|" + $crlf.At + "|" + $crlf.Files[".claude/a.md"].Id) "etat en CRLF relu"
[IO.File]::WriteAllText($script:DriveStatePath, $plain.Replace('"m": 6,', '"m": 6, "x": 1,'))
Assert-Equal "i2" (Read-DriveState).Files[".claude/a.md"].Id "etat avec champ inconnu relu"
Remove-Item -LiteralPath $script:DriveStatePath -Force

foreach ($p in @(".claude/settings.json", ".claude-compte2/settings.json", ".claude/SETTINGS.json", ".claude.json", ".mcp.json", ".claude/.claude.json", ".claude-compte2/.claude.json", ".claude/profiles/x/settings.json", ".claude/plugins/p/.claude.json", ".claude/settings.local.json", ".claudex.json")) {
  Assert-True (-not (Test-MachineSettingsPath $p) -or $script:MachinePathHint.IsMatch($p)) ("reglages machine jamais repris de la base : " + $p)
}
Assert-True (-not $script:MachinePathHint.IsMatch(".claude/profiles/x/settings.json")) "reglages d'un profil : MD5 repris de la base"
