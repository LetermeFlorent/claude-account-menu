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

Assert-Equal ".claude/settings.json.conflit-MAC" (Get-ConflictPath ".claude/settings.json" "MAC") "nom de la copie de conflit"
Assert-Equal "a.md.conflit-PC_BUREAU_" (Get-ConflictPath "a.md" "PC BUREAU!") "nom du PC nettoye dans la copie"
Assert-True (Test-SyncExcluded "a.md.conflit-MAC" (Get-SyncPatterns @())) "copie de conflit jamais synchronisee"
