. (Join-Path $bin "claude-menu-rename.ps1")
. (Join-Path $bin "claude-menu-remove.ps1")
. (Join-Path $bin "claude-cli.ps1")

$cliMocked = @("Connect-NewAccount", "Get-ClaudeVersion", "Test-Network", "Update-Clm", "Update-ClaudeForAccounts", "Get-Backups", "Save-Accounts")
$cliKept = @{}
foreach ($n in $cliMocked) { $cliKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$cliFiles = @{}
foreach ($p in @($script:RegistryPath, $script:UsageCachePath)) { if (Test-Path -LiteralPath $p) { $cliFiles[$p] = [IO.File]::ReadAllBytes($p) } }

function Invoke-CliArgs {
  param([object[]]$ArgList)
  return Invoke-CliCommand (Get-CliCommand $ArgList) $ArgList 6>$null
}

$script:CliCalls = New-Object 'System.Collections.Generic.List[string]'
$script:CliAdded = New-Object 'System.Collections.Generic.List[string]'
function Connect-NewAccount { param([string]$Label) $script:CliAdded.Add($Label); return "ajoute" }
function Get-ClaudeVersion { return "2.1.0" }
function Test-Network { return $script:CliOnline }
function Update-Clm { $script:CliCalls.Add("clm"); return $script:CliNewClm }
function Update-ClaudeForAccounts { param($Accounts) $script:CliCalls.Add("claude " + @($Accounts).Count) }
function Save-Accounts { param([string]$Tag, $Accs) $script:CliCalls.Add("archive " + (@($Accs | ForEach-Object { $_.Dir }) -join ",")); return "archive.zip" }

try {
  Assert-Null (Get-CliCommand @()) "cli : sans option, menu"
  Assert-Null (Get-CliCommand @("--resume")) "cli : option de Claude Code, menu"
  Assert-Null (Get-CliCommand @("-2", "--help")) "cli : -2 --help va a Claude Code"
  Assert-Equal "help" (Get-CliCommand @("-h")).Name "cli : -h"
  $c = Get-CliCommand @("--remove", "Pro", "--erase", "--yes")
  Assert-True ($c.Name -eq "remove" -and $c.Values.Count -eq 1 -and $c.Values[0] -eq "Pro" -and $c.Erase -and $c.Yes) "cli : --remove et ses drapeaux"
  Assert-Equal "global:roblox|blender" ((Get-CliCommand @("--prefs-off", "global:roblox", "blender")).Values -join "|") "cli : plusieurs ids"
  Assert-True (-not (Get-CliCommand @("--list")).Yes) "cli : sans --yes"
  Assert-Equal 1 (Invoke-CliCommand @{ Name = "inconnue"; Values = @() } @() 6>$null) "cli : commande inconnue en echec"

  $help = Get-CliHelpLines
  $text = $help -join "`n"
  $documented = @($script:CliCommands + @("--usage", "--save", "--restore=", "--only=", "--no-update", "--drive-login", "--sync", "--force", "--sync-auto=on|off", "--erase", "--yes", "--web", "CLM_ANIM", "STATUSLINE_BG", "display.json", "%LOCALAPPDATA%\clm", "~/.local/state/clm", "~/Library/Application Support/clm"))
  Assert-Equal "" (@($documented | Where-Object { -not $text.Contains($_) }) -join ",") "aide : chaque option decrite"
  Assert-Equal "" (@($help | Where-Object { $_.Length -gt 80 }) -join "|") "aide : 80 colonnes au plus"
  if ((Get-ClmLang) -eq "en") { Assert-Equal "" (@($help | Where-Object { $_ -match "[^\x20-\x7E]" }) -join "|") "aide : ascii" }
  $footer = @{}
  for ($i = 0; $i + 1 -lt $script:MenuFooter.Count; $i += 2) { $footer[$script:MenuFooter[$i]] = $script:MenuFooter[$i + 1] }
  Assert-True ($help -contains ("  " + "p".PadRight(8) + $footer["p"])) "aide : touches du menu"
  Assert-True ($help -contains ("  " + "w".PadRight(8) + $footer["w"])) "aide : touche de la page web"
  Assert-Equal 0 (Invoke-CliArgs @("--help")) "aide : reussie"

  Save-Registry @(
    [PSCustomObject]@{ Label = "compte1"; Dir = ".claude" },
    [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" },
    [PSCustomObject]@{ Label = "perso"; Dir = ".claude-compte3" }
  )
  $null = New-SandboxFile ".claude-compte2/.claude.json" '{"oauthAccount": {"emailAddress": "pro@exemple.fr"}}'
  $accs = @(Get-Accounts)
  Assert-Equal "Pro" (Find-CliAccount $accs "2").Label "compte par numero"
  Assert-Equal ".claude-compte3" (Find-CliAccount $accs "PERSO").Dir "compte par nom, sans casse"
  Assert-Equal "perso" (Find-CliAccount $accs ".claude-compte3").Label "compte par dossier"
  $err = ""
  try { $null = Find-CliAccount $accs "9" } catch { $err = $_.Exception.Message }
  Assert-Equal (Get-ClmText "accounts.cli.unknownAccount" @("9")) $err "numero sans compte"
  $list = Get-CliAccountLines
  Assert-Equal 3 $list.Count "--list : une ligne par compte"
  Assert-Equal "2  Pro          .claude-compte2    pro@exemple.fr" $list[1] "--list : numero, nom, dossier, e-mail"
  Assert-Equal "3  perso        .claude-compte3" $list[2] "--list : compte sans e-mail"

  Assert-Equal 0 (Invoke-CliArgs @("--rename", "2", "Travail")) "--rename : reussi"
  Assert-Equal "Travail" (Get-Accounts)[1].Label "--rename : nom ecrit"
  Assert-Equal 1 (Invoke-CliArgs @("--rename", "Travail")) "--rename sans nouveau nom : echec"
  Assert-Equal 1 (Invoke-CliArgs @("--rename", "Travail", "perso")) "--rename vers un nom pris : echec"

  Assert-Equal 1 (Invoke-CliArgs @("--add", "travail")) "--add nom pris : refuse"
  Assert-Equal 1 (Invoke-CliArgs @("--add", "a,b")) "--add avec virgule : refuse"
  Assert-Equal 1 (Invoke-CliArgs @("--add", "a", "b")) "--add deux noms : refuse"
  Assert-Equal 0 $script:CliAdded.Count "--add refuse : aucun compte cree"
  Assert-Equal 0 (Invoke-CliArgs @("--add")) "--add sans nom : reussi"
  Assert-Equal 0 (Invoke-CliArgs @("--add", " Neuf ")) "--add avec nom : reussi"
  Assert-Equal "|Neuf" ($script:CliAdded -join "|") "--add : nom par defaut puis nom sans espaces autour"

  Assert-Equal 1 (Invoke-CliArgs @("--remove", "perso")) "--remove sans --yes : refuse"
  Assert-Equal 3 @(Get-Accounts).Count "--remove sans --yes : rien retire"
  Assert-Equal 1 (Invoke-CliArgs @("--remove", "1", "--erase", "--yes")) "--remove --erase sur .claude : refuse"
  Assert-Equal 1 (Invoke-CliArgs @("--remove", "--yes")) "--remove sans compte : refuse"
  $null = New-SandboxFile ".claude-compte3/a.txt" "a"
  Assert-Equal 0 (Invoke-CliArgs @("--remove", "perso", "--erase", "--yes")) "--remove --erase --yes : reussi"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Sandbox ".claude-compte3"))) "--remove --erase : dossier efface"
  Assert-Equal "archive .claude-compte3" ($script:CliCalls -join "|") "--remove --erase : archive d'abord"
  Assert-Equal "compte1,Travail" (@(Get-Accounts | ForEach-Object { $_.Label }) -join ",") "--remove : compte retire de la liste"

  $v = Get-CliVersionLines
  Assert-True ($v[0].StartsWith("clm ") -and $v[1].EndsWith((Get-ClmText "accounts.cli.notInstalledHere")) -and $v[2] -eq "Claude Code 2.1.0") "--version : clm, dossier, Claude Code"
  function Get-Backups { return @([PSCustomObject]@{ LastWriteTime = [datetime]::new(2026, 10, 21, 9, 5, 0); FullName = "/t/claude-comptes-x.zip" }) }
  Assert-Equal "21/10/2026 09:05  /t/claude-comptes-x.zip" (Get-CliBackupLines)[0] "--backups : date et chemin"
  function Get-Backups { return @() }
  Assert-Equal (Get-ClmText "accounts.cli.noBackups" @((Get-DownloadsDir))) (Get-CliBackupLines)[0] "--backups sans archive"

  $script:CliCalls.Clear()
  $script:CliOnline = $false
  Assert-Equal 1 (Invoke-CliArgs @("--update")) "--update sans reseau : echec"
  Assert-Equal 0 $script:CliCalls.Count "--update sans reseau : rien tente"
  $script:CliOnline = $true
  $script:CliNewClm = $false
  Assert-Equal 0 (Invoke-CliArgs @("--update")) "--update : reussi"
  Assert-Equal "clm|claude 2" ($script:CliCalls -join "|") "--update : clm puis Claude Code de chaque compte"
  Assert-True (-not $script:CliRestart) "--update sans nouvelle version : pas de redemarrage"
  $script:CliCalls.Clear()
  $script:CliNewClm = $true
  Assert-Equal 0 (Invoke-CliArgs @("--update")) "--update avec nouvelle version de clm : reussi"
  Assert-True ($script:CliRestart -and ($script:CliCalls -join "|") -eq "clm") "--update : nouvelle version de clm, Claude Code laisse au redemarrage"
  $script:CliRestart = $false
  $script:CliCalls.Clear()
  Assert-Equal 0 (Invoke-CliArgs @("--update", "--updated")) "--update apres redemarrage : reussi"
  Assert-Equal "claude 2" ($script:CliCalls -join "|") "--update apres redemarrage : clm pas recherche"
} finally {
  foreach ($n in $cliMocked) { Set-Item -Path ("function:" + $n) -Value $cliKept[$n] }
  foreach ($p in @($script:RegistryPath, $script:UsageCachePath)) {
    if ($cliFiles.ContainsKey($p)) { [IO.File]::WriteAllBytes($p, $cliFiles[$p]) } else { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
  }
  Remove-Item -LiteralPath (Join-Path $script:Sandbox ".claude-compte2"), (Join-Path $script:Sandbox ".claude-compte3") -Recurse -Force -ErrorAction SilentlyContinue
}
