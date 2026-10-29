. (Join-Path $bin "claude-usage-poll.ps1")
. (Join-Path $bin "claude-cli.ps1")

$pollPath = Get-DisplayPath
function Write-PollFile {
  param([string]$Text)
  New-Item -ItemType Directory -Force -Path (Split-Path $pollPath) | Out-Null
  [IO.File]::WriteAllText($pollPath, $Text, (New-Object Text.UTF8Encoding($false)))
}

try {
  Remove-Item -LiteralPath $pollPath -Force -ErrorAction SilentlyContinue
  Assert-Equal 30 (Read-UsagePollSeconds) "delai de lecture sans fichier, 30"
  Write-PollFile '{ "usagePoll": 45 }'
  Assert-Equal 45 (Read-UsagePollSeconds) "delai de lecture ecrit relu"
  Write-PollFile '{ "usagePoll": 5 }'
  Assert-Equal 15 (Read-UsagePollSeconds) "delai trop court remonte a 15"
  Write-PollFile '{ "usagePoll": 9999 }'
  Assert-Equal 600 (Read-UsagePollSeconds) "delai trop long ramene a 600"
  Write-PollFile '{ "usagePoll": "abc" }'
  Assert-Equal 30 (Read-UsagePollSeconds) "delai non entier, 30"
  Write-PollFile '{ "palette": "dark" }'
  Assert-Equal 30 (Read-UsagePollSeconds) "delai absent du fichier, 30"
  Write-PollFile '{ "usagePoll": '
  Assert-Equal 30 (Read-UsagePollSeconds) "fichier corrompu, delai 30"

  Write-PollFile '{ "palette": "light", "anim": "off", "foo": "bar" }'
  Assert-Equal 90 (Set-DisplayUsagePoll 90) "reglage du delai rend l'entier ecrit"
  Assert-Equal 90 (Read-UsagePollSeconds) "reglage du delai relu"
  $kept = Read-DisplayConfig
  Assert-Equal "light off" ($kept.palette + " " + $kept.anim) "reglage du delai garde palette et animations"
  Assert-Equal "bar" (Read-JsonFile $pollPath)["foo"] "reglage du delai garde une cle inconnue"
  Assert-Equal 120 (Set-DisplayUsagePoll "120") "reglage du delai accepte des chiffres"
  Assert-True ([IO.File]::ReadAllText($pollPath).EndsWith("}`n")) "fichier du delai fini par un retour a la ligne"
  Assert-Throws { Set-DisplayUsagePoll "abc" } "delai de lecture inconnu : abc, choisir un nombre de secondes entre 15 et 600" "delai texte refuse"
  Assert-Throws { Set-DisplayUsagePoll 14 } "entre 15 et 600" "delai 14 refuse"
  Assert-Throws { Set-DisplayUsagePoll 601 } "entre 15 et 600" "delai 601 refuse"
  Assert-Equal 120 (Read-UsagePollSeconds) "refus sans rien changer"

  Write-PollFile '{ "usagePoll": '
  Assert-Equal 20 (Set-DisplayUsagePoll 20) "fichier corrompu remplace par le delai"
  Assert-Equal 1 @((Read-JsonFile $pollPath).Keys).Count "fichier corrompu devenu fichier du seul delai"

  Remove-Item -LiteralPath $pollPath -Force -ErrorAction SilentlyContinue
  $cmd = Get-CliCommand @("--usage-poll", "45")
  $lines = @(Invoke-CliCommand $cmd @("--usage-poll", "45") 6>&1 | ForEach-Object { "" + $_ })
  Assert-Equal "lecture de l'API de suivi de ce PC : toutes les 45 s|0" ($lines -join "|") "cli delai de lecture ecrit"
  Assert-Equal 45 (Read-UsagePollSeconds) "cli delai de lecture relu"
  $lines = @(Invoke-CliCommand (Get-CliCommand @("--usage-poll")) @("--usage-poll") 6>&1 | ForEach-Object { "" + $_ })
  Assert-Equal "--usage-poll attend un nombre de secondes entre 15 et 600|1" ($lines -join "|") "cli delai de lecture manquant"
  $lines = @(Invoke-CliCommand (Get-CliCommand @("--usage-poll", "3")) @("--usage-poll", "3") 6>&1 | ForEach-Object { "" + $_ })
  Assert-Equal 1 $lines[-1] "cli delai de lecture trop court refuse"
  Assert-Equal 45 (Read-UsagePollSeconds) "cli refus sans rien changer"
} finally { Remove-Item -LiteralPath $pollPath -Force -ErrorAction SilentlyContinue }
