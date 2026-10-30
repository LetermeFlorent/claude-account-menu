. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")

function Get-TopNames {
  param([string]$Rel)
  $m = Read-McpFile (Join-Path $script:HomeDir $Rel)
  if ($null -eq $m) { return "absent" }
  return (@($m.Keys) | Sort-Object) -join ","
}

function Invoke-GlobalPass {
  param($Prefs, [string]$Name)
  Assert-Equal 0 (Sync-GlobalMcp $Prefs $globAccs) ($Name + " : aucun echec")
}

function Set-GlobalCheck {
  param([string]$GlobalName, [bool]$GlobalChecked)
  return Update-SyncChoice { param($c) Set-ChoiceCheck $c "globals" $GlobalName $GlobalChecked $true }
}

$globAccs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "compte2"; Dir = ".claude-c2" })
Use-Pc "GA"
Set-PcFile ".claude.json" '{"tips": 1, "mcpServers": {"roblox": {"command": "r"}, "garde": {"command": "g"}}}'
Set-PcFile ".claude-c2/.claude.json" '{"mcpServers": {"roblox": {"command": "r"}, "garde": {"command": "g"}}}'
$gp = @{ Catalog = (New-SyncCatalog); Choice = (Read-SyncChoice) }
Invoke-GlobalPass $gp "premier passage"
Assert-Equal "garde,roblox" ((@($gp.Catalog.Globals) | Sort-Object) -join ",") "globaux vus notes"
Assert-Equal "garde,roblox" (Get-TopNames ".claude.json") "globaux coches gardes"

$gp.Choice = Set-GlobalCheck "roblox" $false
Invoke-GlobalPass $gp "decoche"
Assert-Equal "garde" (Get-TopNames ".claude.json") "global decoche : retire du premier compte"
Assert-Equal "garde" (Get-TopNames ".claude-c2/.claude.json") "global decoche : retire des autres comptes"
Assert-Equal '{"command":"r"}' $gp.Catalog.Parked["roblox"] "global decoche : mis de cote"
Assert-True ((Get-PcText ".claude.json").Contains('"tips": 1')) "global decoche : reste de la config garde"
Invoke-GlobalPass $gp "decoche, second passage"
Assert-True ($gp.Catalog.Parked.ContainsKey("roblox") -and (Test-GlobalOff (Read-SyncChoice) "roblox")) "global decoche : reste decoche et de cote"

$gp.Choice = Set-GlobalCheck "roblox" $true
Invoke-GlobalPass $gp "recoche"
Assert-Equal "garde,roblox" (Get-TopNames ".claude.json") "global recoche : remis dans le premier compte"
Assert-Equal "garde,roblox" (Get-TopNames ".claude-c2/.claude.json") "global recoche : remis dans les autres comptes"
Assert-True (-not $gp.Catalog.Parked.ContainsKey("roblox")) "global recoche : plus de cote"

$gp.Choice = Set-GlobalCheck "roblox" $false
Invoke-GlobalPass $gp "decoche encore"
Set-PcFile ".claude.json" '{"tips": 1, "mcpServers": {"roblox": {"command": "r2"}, "garde": {"command": "g"}}}'
Invoke-GlobalPass $gp "remis a la main"
Assert-True (-not (Test-GlobalOff (Read-SyncChoice) "roblox")) "global remis a la main : recoche"
Assert-Equal '{"command":"r2"}' (Read-McpFile (Join-Path $script:HomeDir ".claude-c2/.claude.json"))["roblox"] "global remis a la main : nouvelle definition dans les autres comptes"

$gp.Choice = Update-SyncChoice { param($c) Add-EraseRequest $c "globals" "roblox" }
Invoke-GlobalPass $gp "efface"
Assert-Equal "garde" (Get-TopNames ".claude.json") "global efface : retire"
Assert-True (-not $gp.Catalog.Parked.ContainsKey("roblox")) "global efface : oublie"
Assert-Equal 0 (Read-SyncChoice).Erase.globals.Count "global efface : demande retiree"

$session = Register-DriveSession ([PSCustomObject]@{ Dir = ".claude-c2" })
$gp.Choice = Set-GlobalCheck "garde" $false
Invoke-GlobalPass $gp "compte ouvert"
Assert-Equal "" (Get-TopNames ".claude.json") "compte ferme : global retire"
Assert-Equal "garde" (Get-TopNames ".claude-c2/.claude.json") "compte ouvert : config jamais ecrite"
$null = Close-DriveSession $session
Invoke-GlobalPass $gp "compte referme"
Assert-Equal "" (Get-TopNames ".claude-c2/.claude.json") "compte referme : global retire"

Set-PcFile ".claude-c2/.claude.json" '{"mcpServers": {'
Invoke-GlobalPass $gp "config illisible"
Assert-Equal '{"mcpServers": {' (Get-PcText ".claude-c2/.claude.json") "config illisible : jamais ecrite"

Use-Pc "GB"
Save-Registry $globAccs
Set-PcFile ".claude.json" '{"mcpServers": {"blender": {"command": "b"}}}'
$null = Set-GlobalCheck "blender" $false
$null = Send-FakePresence "OLD.json" ([Text.Encoding]::UTF8.GetBytes("{}")) @{ fmt = "2" }
$r = Invoke-DriveSync
Assert-True ($r.Ok -and $r.Failed -eq 0) ("ancien PC present " + $r.Error)
Assert-Equal "blender" (Get-TopNames ".claude.json") "ancien PC present : globaux decoches laisses en place"
$script:Fake.Clear()
$script:FakePresence.Clear()
Restore-FakeDrive
. (Join-Path $bin "drive/core/claude-drive-creds.ps1")
