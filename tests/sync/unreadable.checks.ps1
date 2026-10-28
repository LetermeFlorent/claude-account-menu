. (Join-Path $PSScriptRoot "fake-drive.ps1")

Use-Pc "UN"
Save-Registry @([PSCustomObject]@{ Label = "c1"; Dir = ".claude" })
Set-PcFile ".claude/a.md" "x" 1700000000

Assert-Equal 0 (Read-DriveState).Files.Count "etat absent : vide"
[IO.File]::WriteAllText($script:DriveStatePath, "pas du json")
Assert-Throws { Read-DriveState } "illisible" "etat illisible : lecture en erreur, pas etat vide"
$r = Invoke-DriveSync
Assert-True (-not $r.Ok) "etat illisible : synchro en echec"
Assert-True ($r.Error.Contains("illisible")) "etat illisible : raison donnee"
Assert-Equal "pas du json" ([IO.File]::ReadAllText($script:DriveStatePath)) "etat illisible : fichier intact"
Assert-Equal 0 $script:Fake.Count "etat illisible : rien envoye au Drive"
[IO.File]::WriteAllText($script:DriveStatePath, "")
Assert-Throws { Read-DriveState } "illisible" "etat vide : lecture en erreur"
Remove-Item -LiteralPath $script:DriveStatePath -Force
$r = Invoke-DriveSync
Assert-True $r.Ok ("etat absent : premiere synchro " + $r.Error)

$presenceName = "PX.json"
$script:FakePresence[$presenceName] = @{ Id = "p-px"; Name = $presenceName; Props = @{}; Bytes = [Text.Encoding]::UTF8.GetBytes("pas du json"); Md5 = "m1" }
Assert-Null (Read-PcFile "p-px") "fiche de PC illisible : rien lu"
$script:FakePresence[$presenceName].Bytes = [Text.Encoding]::UTF8.GetBytes("[1]")
Assert-Null (Read-PcFile "p-px") "fiche de PC qui n'est pas un objet : rien lu"
$script:FakePresence[$presenceName].Bytes = [Text.Encoding]::UTF8.GetBytes("{}")
Assert-True ($null -ne (Read-PcFile "p-px")) "fiche de PC vide mais valide : lue"
$script:FakePresence[$presenceName].Bytes = [Text.Encoding]::UTF8.GetBytes("pas du json")
$catalog = New-SyncCatalog
$known = New-PcContent
$known.Md5 = "m0"
$known.Mcp["k"] = @{ At = [long]5; Deleted = $false; Os = "Windows"; Def = '{"command":"x"}' }
$catalog.Pcs["PX"] = $known
Update-PcFiles $catalog (Get-DriveListing "P")
Assert-Equal "m0" $catalog.Pcs["PX"].Md5 "fiche de PC illisible : contenu connu garde"
Assert-True $catalog.Pcs["PX"].Mcp.ContainsKey("k") "fiche de PC illisible : serveurs MCP connus gardes"
$script:FakePresence.Remove($presenceName)
Update-PcFiles $catalog (Get-DriveListing "P")
Assert-True (-not $catalog.Pcs.ContainsKey("PX")) "fiche de PC disparue du Drive : retiree du catalogue"

Restore-FakeDrive
