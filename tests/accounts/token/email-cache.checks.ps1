$mailAcc = [PSCustomObject]@{ Label = "mailcache"; Dir = ".claude-mailcache" }
$mailFile = New-SandboxFile ".claude-mailcache/.claude.json" '{"oauthAccount":{"emailAddress":"first@x.fr"}}'
$mailOld = [DateTime]::SpecifyKind([DateTime]"2020-01-01 10:00:00", [DateTimeKind]::Utc)
[IO.File]::SetLastWriteTimeUtc($mailFile, $mailOld)
$script:AccountEmailReads = 0

Assert-Equal "first@x.fr" (Get-AccountEmail $mailAcc) "cache courriel : premiere lecture"
Assert-Equal "first@x.fr" (Get-AccountEmail $mailAcc) "cache courriel : deuxieme appel"
Assert-Equal "first@x.fr" (Get-AccountEmail $mailAcc) "cache courriel : troisieme appel"
Assert-Equal 1 $script:AccountEmailReads "cache courriel : fichier inchange, une seule lecture"

[IO.File]::WriteAllText($mailFile, '{"oauthAccount":{"emailAddress":"second-longer@x.fr"}}')
[IO.File]::SetLastWriteTimeUtc($mailFile, $mailOld.AddSeconds(5))
Assert-Equal "second-longer@x.fr" (Get-AccountEmail $mailAcc) "cache courriel : taille changee, nouveau courriel"
Assert-Equal 2 $script:AccountEmailReads "cache courriel : taille changee, seconde lecture"
Assert-Equal "second-longer@x.fr" (Get-AccountEmail $mailAcc) "cache courriel : apres changement, cache"
Assert-Equal 2 $script:AccountEmailReads "cache courriel : apres changement, pas de lecture"

[IO.File]::WriteAllText($mailFile, '{"oauthAccount":{"emailAddress":"second-longer@y.fr"}}')
[IO.File]::SetLastWriteTimeUtc($mailFile, $mailOld.AddSeconds(9))
Assert-Equal "second-longer@y.fr" (Get-AccountEmail $mailAcc) "cache courriel : meme taille, date changee, nouveau courriel"
Assert-Equal 3 $script:AccountEmailReads "cache courriel : meme taille, date changee, relecture"

Remove-Item -LiteralPath $mailFile -Force
Assert-Equal "" (Get-AccountEmail $mailAcc) "cache courriel : fichier supprime"
Assert-Equal "" (Get-AccountEmail $mailAcc) "cache courriel : fichier absent, encore vide"

[IO.File]::WriteAllText($mailFile, '{"oauthAccount":{"emailAddress":"back@x.fr"}}')
Assert-Equal "back@x.fr" (Get-AccountEmail $mailAcc) "cache courriel : fichier recree"

$quickReads = $script:AccountEmailReads
[IO.File]::WriteAllText($mailFile, '{"oauthAccount":{"emailAddress":"fast01@x.fr"}}')
$quickA = Get-AccountEmail $mailAcc
[IO.File]::WriteAllText($mailFile, '{"oauthAccount":{"emailAddress":"fast02@x.fr"}}')
$quickB = Get-AccountEmail $mailAcc
Assert-Equal "fast01@x.fr fast02@x.fr" ($quickA + " " + $quickB) "cache courriel : reecriture rapide de meme taille"
Assert-True ($script:AccountEmailReads -ge $quickReads + 2) "cache courriel : reecriture rapide relue"
Remove-Item -LiteralPath $mailFile -Force -ErrorAction SilentlyContinue
