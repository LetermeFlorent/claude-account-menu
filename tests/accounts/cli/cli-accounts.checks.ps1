. (Join-Path $bin "cli/claude-cli.ps1")

$cliMocked = @("Get-ClaudeVersion", "Test-Network", "Update-Clm", "Update-ClaudeForAccounts", "Get-Backups")
$cliKept = @{}
foreach ($n in $cliMocked) { $cliKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$cliFiles = @{}
foreach ($p in @($script:RegistryPath, $script:UsageCachePath)) { if (Test-Path -LiteralPath $p) { $cliFiles[$p] = [IO.File]::ReadAllBytes($p) } }

function Invoke-CliArgs {
  param([object[]]$ArgList)
  return Invoke-CliCommand (Get-CliCommand $ArgList) $ArgList 6>$null
}

$script:CliCalls = New-Object 'System.Collections.Generic.List[string]'
function Get-ClaudeVersion { return "2.1.0" }
function Test-Network { return $script:CliOnline }
function Update-Clm { $script:CliCalls.Add("clm"); return $script:CliNewClm }
function Update-ClaudeForAccounts { param($Accounts) $script:CliCalls.Add("claude " + @($Accounts).Count) }

try {
  Assert-Null (Get-CliCommand @()) "cli : sans option, menu"
  Assert-Null (Get-CliCommand @("--resume")) "cli : option de Claude Code, menu"
  Assert-Null (Get-CliCommand @("-2", "--help")) "cli : -2 --help va a Claude Code"
  Assert-Equal "help" (Get-CliCommand @("-h")).Name "cli : -h"
  Assert-Equal "True True True True" ((@("--version"), @("--help"), @("-h"), @("--list") | ForEach-Object { Test-CliQuick $_ }) -join " ") "cli : version, aide et liste sans le menu"
  Assert-Equal "False False False False" ((@(), @("--backups"), @("-2", "--help"), @("--prefs") | ForEach-Object { Test-CliQuick $_ }) -join " ") "cli : autres options avec le menu"
  Assert-Equal 1 (Invoke-CliCommand @{ Name = "inconnue"; Values = @() } @() 6>$null) "cli : commande inconnue en echec"

  $help = Get-CliHelpLines
  $text = $help -join "`n"
  $documented = @($script:CliCommands + @("--usage", "--no-update", "--sync", "--force", "--sync-key", "--sync-key-reset", "--sync-key-forget", "--web", "CLM_ANIM", "STATUSLINE_BG", "display.json", "%LOCALAPPDATA%\clm", "~/.local/state/clm", "~/Library/Application Support/clm"))
  Assert-Equal "" (@($documented | Where-Object { -not $text.Contains($_) }) -join ",") "aide : chaque option decrite"
  Assert-Equal "" (@($help | Where-Object { $_.Length -gt 80 }) -join "|") "aide : 80 colonnes au plus"
  if ((Get-ClmLang) -eq "en") { Assert-Equal "" (@($help | Where-Object { $_ -match "[^\x20-\x7E]" }) -join "|") "aide : ascii" }
  Assert-True ($help -contains ("  y       " + (Get-ClmText "ui.footer.sync"))) "aide : touches du menu"
  Assert-True ($help -contains ("  w       " + (Get-ClmText "ui.footer.web"))) "aide : touche de la page web"
  Assert-Equal 0 (Invoke-CliArgs @("--help")) "aide : reussie"

  Save-Registry @(
    [PSCustomObject]@{ Label = "compte1"; Dir = ".claude" },
    [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" },
    [PSCustomObject]@{ Label = "perso"; Dir = ".claude-compte3" }
  )
  $null = New-SandboxFile ".claude-compte2/.claude.json" '{"oauthAccount": {"emailAddress": "pro@exemple.fr"}}'
  $list = Get-CliAccountLines
  Assert-Equal 3 $list.Count "--list : une ligne par compte"
  Assert-Equal "2  Pro          .claude-compte2    pro@exemple.fr" $list[1] "--list : numero, nom, dossier, e-mail"
  Assert-Equal "3  perso        .claude-compte3" $list[2] "--list : compte sans e-mail"

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
  Assert-Equal "clm|claude 3" ($script:CliCalls -join "|") "--update : clm puis Claude Code de chaque compte"
  Assert-True (-not $script:CliRestart) "--update sans nouvelle version : pas de redemarrage"
  $script:CliCalls.Clear()
  $script:CliNewClm = $true
  Assert-Equal 0 (Invoke-CliArgs @("--update")) "--update avec nouvelle version de clm : reussi"
  Assert-True ($script:CliRestart -and ($script:CliCalls -join "|") -eq "clm") "--update : nouvelle version de clm, Claude Code laisse au redemarrage"
  $script:CliRestart = $false
  $script:CliCalls.Clear()
  Assert-Equal 0 (Invoke-CliArgs @("--update", "--updated")) "--update apres redemarrage : reussi"
  Assert-Equal "claude 3" ($script:CliCalls -join "|") "--update apres redemarrage : clm pas recherche"
} finally {
  foreach ($n in $cliMocked) { Set-Item -Path ("function:" + $n) -Value $cliKept[$n] }
  foreach ($p in @($script:RegistryPath, $script:UsageCachePath)) {
    if ($cliFiles.ContainsKey($p)) { [IO.File]::WriteAllBytes($p, $cliFiles[$p]) } else { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
  }
  Remove-Item -LiteralPath (Join-Path $script:Sandbox ".claude-compte2"), (Join-Path $script:Sandbox ".claude-compte3") -Recurse -Force -ErrorAction SilentlyContinue
}
