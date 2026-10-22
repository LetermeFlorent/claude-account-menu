function New-L { param([string]$Md5, [long]$M = 10) return @{ Md5 = $Md5; M = $M; Size = 1; Full = "" } }
function New-B { param([string]$Md5) return @{ Md5 = $Md5; M = 10; Size = 1; Id = "i" } }
function New-R { param([string]$Md5, [long]$M = 10) return @{ Id = "i"; Md5 = $Md5; M = $M; Pc = "MAC" } }

Assert-Null (Get-PathAction $null $null $null) "rien nulle part"
Assert-Null (Get-PathAction (New-L "a") (New-B "a") (New-R "a")) "identique partout, rien a faire"
Assert-Equal "upload" (Get-PathAction (New-L "a") $null $null) "nouveau fichier local envoye"
Assert-Equal "download" (Get-PathAction $null $null (New-R "a")) "nouveau fichier distant recu"
Assert-Equal "upload" (Get-PathAction (New-L "b") (New-B "a") (New-R "a")) "modifie localement, envoye"
Assert-Equal "download" (Get-PathAction (New-L "a") (New-B "a") (New-R "b")) "modifie ailleurs, recu"
Assert-Equal "adopt" (Get-PathAction (New-L "b") (New-B "a") (New-R "b")) "meme modification des deux cotes, base mise a jour"
Assert-Equal "adopt" (Get-PathAction (New-L "b") $null (New-R "b")) "meme contenu sans base, base creee"
Assert-Equal "keep-local" (Get-PathAction (New-L "b" 50) (New-B "a") (New-R "c" 40)) "conflit gagne par le local plus recent"
Assert-Equal "keep-remote" (Get-PathAction (New-L "b" 30) (New-B "a") (New-R "c" 40)) "conflit gagne par le distant plus recent"
Assert-Equal "keep-local" (Get-PathAction (New-L "b" 50) $null (New-R "c" 40)) "conflit sans base, le plus recent gagne"
Assert-Equal "keep-remote" (Get-PathAction (New-L "b" 50) $null (New-R "c" 40) -Joining) "premier passage du PC : le Drive gagne, le local garde en copie"
Assert-Equal "keep-local" (Get-PathAction (New-L "b" 50) (New-B "a") (New-R "c" 40) -Joining) "premier passage, fichier deja connu : le plus recent gagne"
$jp = Get-SyncPlan @{ "x" = (New-L "b" 50) } @{} @{ "x" = (New-R "c" 40) } @() -Joining
Assert-Equal "keep-remote" $jp[0].Kind "plan du premier passage : le Drive gagne"
Assert-Equal "delete-remote" (Get-PathAction $null (New-B "a") (New-R "a")) "supprime ici, supprime sur le Drive"
Assert-Equal "download" (Get-PathAction $null (New-B "a") (New-R "b")) "supprime ici mais modifie ailleurs, recu"
Assert-Equal "delete-local" (Get-PathAction (New-L "a") (New-B "a") $null) "supprime ailleurs, supprime ici"
Assert-Equal "upload" (Get-PathAction (New-L "b") (New-B "a") $null) "supprime ailleurs mais modifie ici, renvoye"
Assert-Equal "forget" (Get-PathAction $null (New-B "a") $null) "supprime des deux cotes, oublie"

$local = New-PathMap; $base = New-PathMap; $remote = New-PathMap
$remote[".claude/projects/p/x.jsonl"] = New-R "a"
$remote[".claude/settings.json"] = New-R "b"
$remote[".claude-accounts.json"] = New-R "c"
$plan = Get-SyncPlan $local $base $remote
Assert-Equal "download,download,download" (($plan | ForEach-Object { $_.Kind }) -join ",") "PC neuf : tout est recu, rien n'est supprime"
Assert-Equal ".claude-accounts.json|.claude/settings.json|.claude/projects/p/x.jsonl" (($plan | ForEach-Object { $_.Path }) -join "|") "config avant les conversations"

$base[".claude/locked/a.md"] = New-B "a"; $remote[".claude/locked/a.md"] = New-R "a"
$base[".claude/busy.json"] = New-B "a"; $remote[".claude/busy.json"] = New-R "a"
$plan = Get-SyncPlan $local $base $remote @(".claude/locked", ".claude/busy.json")
Assert-True (@($plan | Where-Object { $_.Path -like ".claude/locked*" -or $_.Path -eq ".claude/busy.json" }).Count -eq 0) "dossier ou fichier illisible : aucune action"
Assert-Equal 3 $plan.Count "le reste du plan garde"

$local = New-PathMap; $base = New-PathMap; $remote = New-PathMap
$local[".claude/a.md"] = New-L "n"
$local[".claude/z.md"] = New-L "s"; $remote[".claude/z.md"] = New-R "s"
$base[".claude/parti.md"] = New-B "g"
Assert-Equal "forget,adopt,upload" ((Get-SyncPlan $local $base $remote | ForEach-Object { $_.Kind }) -join ",") "adoptions et oublis en tete du plan"
Assert-Equal "forget,adopt,upload" ((Get-SyncPlan $local $base $remote -CaseFold | ForEach-Object { $_.Kind }) -join ",") "sans doublon de casse, plan inchange"
$local[".claude/A.md"] = New-L "m"; $remote[".claude/a.md"] = New-R "k"
Assert-Equal ".claude/parti.md|.claude/z.md" ((Get-SyncPlan $local $base $remote -CaseFold | ForEach-Object { $_.Path }) -join "|") "doublon de casse ecarte des deux cotes"
Assert-Equal 4 (Get-SyncPlan $local $base $remote).Count "doublon de casse garde si la casse compte"

$listing = New-PathMap
foreach ($k in @(".claude/a.md", ".claude-compte2/b.md", ".claude.json", ".mcp.json", ".CLAUDE/x.md", ".claude-x/y.md", ".claude//b.md", ".claude/../b.md", ".claude/./b.md", ".claude/", "", ".claude\b.md", ".claude/c:d.md", ".autre/z.md", ".claude/node_modules/m.js", ".claudeplus/q.md")) { $listing[$k] = @{ Id = $k } }
$picked = [string[]]@((Select-RemoteFiles $listing (Get-SyncPatterns @()) @(".claude", ".claude-compte2", ".claude.json", "", ".autre")).Keys)
[Array]::Sort($picked, [StringComparer]::Ordinal)
Assert-Equal ".claude-compte2/b.md|.claude.json|.claude/a.md" ($picked -join "|") "Drive : seuls les chemins surs des comptes sont repris"

Assert-Equal ".claude/settings.json.conflit-MAC" (Get-ConflictPath ".claude/settings.json" "MAC") "nom de la copie de conflit"
Assert-Equal "a.md.conflit-PC_BUREAU_" (Get-ConflictPath "a.md" "PC BUREAU!") "nom du PC nettoye dans la copie"
Assert-True (Test-SyncExcluded "a.md.conflit-MAC" (Get-SyncPatterns @())) "copie de conflit jamais synchronisee"
Assert-True (Test-SyncExcluded ".claude/outils/chrome-bidi/profils/comptes/Default/Cookies" (Get-SyncPatterns @())) "profil Chrome jamais synchronise"
Assert-True (-not (Test-SyncExcluded ".claude/outils/chrome-bidi/lancer.ps1" (Get-SyncPatterns @()))) "outil chrome-bidi synchronise hors profils"
$sp = Get-SyncPatterns @()
foreach ($c in @(".claude-compte3/projects/C--Users-x/1f2e.jsonl", ".claude/projects/C--Users-x/1f2e/subagents/agent-a.jsonl", ".claude/projects/C--x/1f2e/tool-results/r.txt", ".claude/outils/omni/node_modules/a/index.js", ".claude/file-history/1f2e/f@v1")) {
  Assert-True (Test-SyncExcluded $c $sp) ("jamais synchronise : " + $c)
}
foreach ($c in @(".claude/projects/C--Users-x/memory/MEMORY.md", ".claude/history.jsonl", ".claude/outils/omni/package.json")) {
  Assert-True (-not (Test-SyncExcluded $c $sp)) ("synchronise : " + $c)
}
$hp = Get-SyncPatterns @([PSCustomObject]@{ Dir = ".claude" }, [PSCustomObject]@{ Dir = ".claude-compte2" })
foreach ($c in @(".claude/skills/.trash/vieux/SKILL.md", ".claude/skills/.brouillon", ".CLAUDE/Skills/.Trash/a.md")) {
  Assert-True (Test-SyncExcluded $c $hp) ("dossier masque des skills jamais synchronise : " + $c)
}
foreach ($c in @(".claude/skills/outil/.git/HEAD", ".claude/skills/outil.v2/SKILL.md", ".claude/plugins/marketplaces/m/.claude-plugin/plugin.json", ".claude/plugins/m/skills/.x/a.md", ".claude/.trash/a.md")) {
  Assert-True (-not (Test-SyncExcluded $c $hp)) ("synchronise hors dossier masque des skills : " + $c)
}
Assert-True (Test-SyncExcluded ".claude/CACHE/x" @("cache")) "exclusion : casse ignoree"
Assert-True (-not (Test-SyncExcluded ".claude/cached/x" @("cache"))) "exclusion : segment entier"
Assert-True ((Test-SyncExcluded ".claude/a.lock" @("*.lock")) -and (Test-SyncExcluded ".claude/a.lock/b" @("*.lock"))) "exclusion : etoile dans un segment"
Assert-True (-not (Test-SyncExcluded ".claude/alock" @("*.lock"))) "exclusion : point litteral"
Assert-True ((Test-SyncExcluded ".local/bin/sub/x.exe" @(".local/bin/*.exe")) -and -not (Test-SyncExcluded ".local/bin2/x.exe" @(".local/bin/*.exe"))) "exclusion : chemin, etoile traverse les dossiers"
Assert-True ((Test-SyncExcluded ".claude/abc" @("a?c")) -and -not (Test-SyncExcluded ".claude/a/c" @("a?c"))) "exclusion : point d'interrogation, un caractere"
Assert-True ((Test-SyncExcluded ".claude/x1" @("x[0-9]")) -and -not (Test-SyncExcluded ".claude/xa" @("x[0-9]"))) "exclusion : crochets"
Assert-True ((Test-SyncExcluded ".claude/a+b(c)" @("a+b(c)")) -and -not (Test-SyncExcluded ".claude/aab(c)" @("a+b(c)"))) "exclusion : caracteres de regex litteraux"
Assert-True (-not (Test-SyncExcluded ".claude/x" @())) "exclusion : aucun motif"
Assert-True ((Test-SyncExcluded ".claude/a*b" @("a``*b")) -and -not (Test-SyncExcluded ".claude/axb" @("a``*b"))) "exclusion : etoile echappee"
Assert-True ((Test-SyncExcluded ".claude/x[1" @("x[1")) -and -not (Test-SyncExcluded ".claude/x1" @("x[1"))) "exclusion : crochet non ferme litteral"
