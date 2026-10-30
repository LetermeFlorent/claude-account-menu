$stRoot = Join-Path $script:Sandbox "etat clm"
$stUnix = $stRoot.Replace("\", "/")
$stLocal = Join-Path $stRoot "local"
Assert-Equal ($stLocal + "\clm") (Get-StateDir "Windows" @{ USERPROFILE = "C:\Users\u"; LOCALAPPDATA = $stLocal }) "dossier de clm Windows"
Assert-Equal ($stUnix + "/xdg/clm") (Get-StateDir "Linux" @{ HOME = $stUnix + "/lin"; XDG_STATE_HOME = $stUnix + "/xdg/" }) "dossier de clm Linux XDG_STATE_HOME"
Assert-Equal ($stUnix + "/lin/.local/state/clm") (Get-StateDir "Linux" @{ HOME = $stUnix + "/lin" }) "dossier de clm Linux par defaut"
Assert-Equal ($stUnix + "/mac/Library/Application Support/clm") (Get-StateDir "MacOS" @{ HOME = $stUnix + "/mac" }) "dossier de clm macOS"
$stHere = Get-StateDir
Assert-True ([IO.Directory]::Exists($stHere) -and $stHere.StartsWith($script:Sandbox)) "dossier de clm cree a la demande, dans le faux dossier perso"
$stOther = @(@("Windows", "Linux") | Where-Object { $_ -ne $script:OsName })[0]
$null = Get-StateDir $stOther @{ HOME = $stUnix + "/autre"; USERPROFILE = (Join-Path $stRoot "autre"); LOCALAPPDATA = (Join-Path $stRoot "autre") }
Assert-True (-not (Test-Path -LiteralPath (Join-Path $stRoot "autre"))) "dossier de clm d'un autre systeme : rien cree"
Assert-Equal "accounts.json|sync-state.json|sync.lock|drive.json|drive-creds.lock|drive-folders.lock|drive-remote.json|drive-state.json|drive.lock|drive-watch|drive-watch.lock|sync-catalog.json|sync-choice.json|sync-choice.lock|display.json" (@($script:StateRenames.Values) -join "|") "table des nouveaux noms"

function New-StateVars {
  param([string]$Name)
  $h = Join-Path $stRoot $Name
  $null = New-Item -ItemType Directory -Path $h -Force
  return @{ USERPROFILE = $h; HOME = $h; LOCALAPPDATA = (Join-Path $h "AppData"); XDG_STATE_HOME = (Join-Path $h "xdg") }
}

function Set-StateText {
  param([string]$Path, [string]$Text)
  $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
  [IO.File]::WriteAllText($Path, $Text)
}

function Get-StateText {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return "absent" }
  return [IO.File]::ReadAllText($Path)
}

$peerRows = @(
  [PSCustomObject]@{ Id = 10; Exe = "powershell.exe"; Line = 'powershell -NoProfile -File "C:\u\.local\bin\claude-menu.ps1" --web' },
  [PSCustomObject]@{ Id = 11; Exe = "/opt/microsoft/powershell/7/pwsh"; Line = "/opt/microsoft/powershell/7/pwsh -NonInteractive -File /home/u/.local/bin/claude-drive-watcher.ps1" },
  [PSCustomObject]@{ Id = 12; Exe = "pwsh"; Line = "pwsh -NoProfile -File /home/u/.local/bin/claude-statusline-seed.ps1" },
  [PSCustomObject]@{ Id = 13; Exe = "sh"; Line = "sh -c pwsh -File /home/u/.local/bin/claude-statusline-seed.ps1" },
  [PSCustomObject]@{ Id = 14; Exe = "pwsh.exe"; Line = "pwsh.exe -File C:\p\tests\run.ps1" },
  [PSCustomObject]@{ Id = 15; Exe = "powershell.exe"; Line = "powershell -File C:\u\.local\bin\claude-menu.ps1" },
  [PSCustomObject]@{ Id = 16; Exe = "pwsh"; Line = "pwsh -File /x/mon-claude-menu.ps1" }
)
Assert-Equal "10|11|12" ((Select-ClmPeers $peerRows 15) -join "|") "autres clm : menu, veilleur et hook, sans ce process ni les autres scripts"
Assert-True (@(Get-ProcessRows | ForEach-Object { [int]$_.Id }) -contains $PID) "liste des process : ce process trouve"
Assert-True (@(Get-ClmPeers) -notcontains $PID) "autres clm : ce process jamais compte"
$peersReal = ${function:Get-ClmPeers}
$script:FakePeers = @()
function Get-ClmPeers { return $script:FakePeers }

$ev = New-StateVars "vide"
$script:FakePeers = @(4242)
Assert-Equal $true (Invoke-StateMigration $ev) "rien a deplacer : pas d'attente des autres clm"
$script:FakePeers = @()

$mv = New-StateVars "maison"
$mh = $mv.HOME
$md = Get-StateDir -Vars $mv
$oldReg = Join-Path $mh ".claude-accounts.json"
$newReg = Join-Path $md "accounts.json"
Assert-Equal $newReg (Get-StatePath "accounts.json" $mv) "chemin : nouveau quand rien n'existe"
Set-StateText $oldReg "ancienne liste"
Assert-Equal $oldReg (Get-StatePath "accounts.json" $mv) "chemin : ancien fichier lu tant qu'il n'est pas deplace"
Assert-Equal (Join-Path $md "autre.json") (Get-StatePath "autre.json" $mv) "chemin : nom sans ancien nom"

Set-StateText (Join-Path $mh ".clm-drive-watch/s1.json") "session"
$held = [IO.File]::Open((Join-Path $mh ".clm-drive-watch.lock"), "OpenOrCreate", "ReadWrite", "None")
try {
  Assert-Equal $false (Invoke-StateMigration $mv) "ancien verrou tenu : migration remise"
  Assert-Equal "ancienne liste|absent|session" (@((Get-StateText $oldReg), (Get-StateText $newReg), (Get-StateText (Join-Path $mh ".clm-drive-watch/s1.json"))) -join "|") "ancien verrou tenu : rien deplace"
} finally { $held.Dispose() }

$script:FakePeers = @(4242)
Assert-Equal $false (Invoke-StateMigration $mv) "autre clm en marche : migration remise"
Assert-Equal "ancienne liste|absent|session" (@((Get-StateText $oldReg), (Get-StateText $newReg), (Get-StateText (Join-Path $mh ".clm-drive-watch/s1.json"))) -join "|") "autre clm en marche : rien deplace"
$script:FakePeers = @()

Set-StateText (Join-Path $mh ".clm-display.json") "vieux reglage"
Set-StateText (Join-Path $md "display.json") "nouveau reglage"
$tmpOld = Join-Path $mh ".clm-drive.json.ab12.tmp"
$tmpNew = Join-Path $mh ".clm-drive.json.cd34.tmp"
$tmpOther = Join-Path $mh "notes.json.ef56.tmp"
foreach ($p in @($tmpOld, $tmpNew, $tmpOther)) { Set-StateText $p "t" }
foreach ($p in @($tmpOld, $tmpOther)) { [IO.File]::SetLastWriteTimeUtc($p, [DateTime]::UtcNow.AddHours(-1)) }
Assert-Equal $true (Invoke-StateMigration $mv) "aucun autre clm, verrou libre : migration faite"
Assert-Equal "absent|ancienne liste" (@((Get-StateText $oldReg), (Get-StateText $newReg)) -join "|") "ancien seul : deplace"
Assert-Equal "session" (Get-StateText (Join-Path $md "drive-watch/s1.json")) "ancien dossier : deplace avec son contenu"
Assert-Equal $newReg (Get-StatePath "accounts.json" $mv) "chemin : nouveau apres la migration"
Assert-Equal "absent|nouveau reglage" (@((Get-StateText (Join-Path $mh ".clm-display.json")), (Get-StateText (Join-Path $md "display.json"))) -join "|") "les deux presents : nouveau garde, ancien supprime"
Assert-Equal "absent|t|t" (@((Get-StateText $tmpOld), (Get-StateText $tmpNew), (Get-StateText $tmpOther)) -join "|") "restes .tmp : anciens effaces, recents et etrangers gardes"
$before = @(Get-ChildItem -LiteralPath $md -Recurse | ForEach-Object { $_.FullName }) -join "|"
Assert-Equal $true (Invoke-StateMigration $mv) "aucun ancien fichier : migration sans effet"
Assert-Equal $before (@(Get-ChildItem -LiteralPath $md -Recurse | ForEach-Object { $_.FullName }) -join "|") "aucun ancien fichier : dossier de clm inchange"

$fv = New-StateVars "bloque"
$fd = Get-StateDir -Vars $fv
[IO.Directory]::Delete($fd)
[IO.File]::WriteAllText($fd, "")
Set-StateText (Join-Path $fv.HOME ".claude-accounts.json") "liste"
$null = Invoke-StateMigration $fv
Assert-Equal "liste" (Get-StateText (Join-Path $fv.HOME ".claude-accounts.json")) "deplacement impossible : ancienne liste gardee"
Assert-Equal (Join-Path $fv.HOME ".claude-accounts.json") (Get-StatePath "accounts.json" $fv) "deplacement impossible : ancienne liste toujours lue"

${function:Get-ClmPeers} = $peersReal
Remove-Item -LiteralPath $stRoot -Recurse -Force
