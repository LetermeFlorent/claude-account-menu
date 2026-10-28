. (Join-Path $bin "claude-menu-archive.ps1")
. (Join-Path $bin "claude-menu-save.ps1")
. (Join-Path $bin "claude-menu-remove.ps1")
$lrHome = $script:HomeDir
$lrRegistry = $script:RegistryPath
$lrRoot = Join-Path $script:Sandbox "liens racine"
$script:HomeDir = Join-Path $lrRoot "maison"
$script:RegistryPath = Join-Path (Join-Path $lrRoot "etat") "accounts.json"
$lrOut = Join-Path $lrRoot "ailleurs"
$null = New-Item -ItemType Directory -Path $script:HomeDir, $lrOut, (Split-Path -Parent $script:RegistryPath) -Force
$null = New-SandboxFile "liens racine/maison/.claude/CLAUDE.md" "regles"
$null = New-SandboxFile "liens racine/maison/.claude-compte2/notes.md" "n"
New-Item -ItemType (Get-DirLinkType) -Path (Join-Path $script:HomeDir ".claude-compte3") -Target $lrOut | Out-Null
$null = New-SandboxFile "liens racine/ailleurs/vole.md" "v"

Assert-True (Test-ReparsePath (Join-Path $script:HomeDir ".claude-compte3")) "lien de dossier reconnu"
Assert-True (-not (Test-ReparsePath (Join-Path $script:HomeDir ".claude-compte2"))) "dossier normal reconnu"
Assert-True (-not (Test-ReparsePath (Join-Path $script:HomeDir "absent"))) "chemin absent : pas un lien"

$lrAccs = @([PSCustomObject]@{ Label = "a"; Dir = ".claude" }, [PSCustomObject]@{ Label = "c"; Dir = ".claude-compte3" })
$lrScan = Get-LocalFiles $script:HomeDir (Get-SyncRoots $lrAccs) (Get-SyncPatterns $lrAccs) (New-PathMap)
Assert-True (-not $lrScan.Files.ContainsKey(".claude-compte3/vole.md")) "synchro : dossier de compte en lien ignore"
Assert-True ($lrScan.Skipped -contains ".claude-compte3") "synchro : dossier de compte en lien marque illisible"

Repair-SharedLinks $lrAccs[1] -Force 3>$null
Assert-True (-not (Test-Path -LiteralPath (Join-Path $lrOut "CLAUDE.md"))) "liens partages : dossier de compte en lien laisse tel quel"

$bsdLines = @("drwxr-xr-x  0 u g 0 Oct 28 10:00 .claude/", "lrwxr-xr-x  0 u g 0 Oct 28 10:00 .claude-compte4 -> /etc", "lrwxr-xr-x  0 u g 0 Oct 28 10:00 .claude/skills -> /tmp", "hrw-r--r--  0 u g 0 Oct 28 10:00 .claude.json link to x")
$gnuLines = @("lrwxrwxrwx u/g 0 2026-10-28 10:00 .claude-compte5/ -> /x", "-rw-r--r-- u/g 3 2026-10-28 10:00 .claude-compte6 -> y.md")
Assert-Equal ".claude-compte4|.claude.json" ((Get-TarLinkRoots $bsdLines) -join "|") "archive : liens a la racine reperes (bsdtar)"
Assert-Equal ".claude-compte5" ((Get-TarLinkRoots $gnuLines) -join "|") "archive : liens a la racine reperes (GNU tar)"

Save-Registry @([PSCustomObject]@{ Label = "a"; Dir = ".claude" })
$null = New-SandboxFile "liens racine/source/.claude-compte3/dedans.md" "d"
Initialize-Tar
$lrZip = Join-Path $lrRoot ("arch" + (Get-ArchiveExtension $script:TarFlavor))
& $script:Tar -a -c -f $lrZip -C (Join-Path $lrRoot "source") ".claude-compte3"
Assert-Throws { Restore-Accounts $lrZip } "lien" "restauration : dossier de compte en lien sur ce PC refuse"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $lrOut "dedans.md"))) "restauration : rien ecrit a travers le lien"

Remove-LinkOrTree (Join-Path $script:HomeDir ".claude-compte3")
Remove-Item -LiteralPath $lrRoot -Recurse -Force
$script:HomeDir = $lrHome
$script:RegistryPath = $lrRegistry
