. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "sync/fakes") "fake-drive.ps1")
. (Join-Path $PSScriptRoot "settings-text.ps1")
$rel = ".claude/settings.json"
$slA = '"statusLine": { "type": "command", "command": "powershell -File \"C:/Users/a/.local/bin/statusline.ps1\"" }'
$slB = '"statusLine": { "type": "command", "command": "pwsh -File \"/home/b/.local/bin/statusline.ps1\"" }'
$canonHooks = New-SeedHooksMember (Get-SeedHookCommand "Windows")
$localHooks = New-SeedHooksMember (Get-SeedHookCommand $script:OsName)
$foreignHooks = New-SeedHooksMember 'pwsh -NoProfile -File "/home/perso/.local/bin/claude-statusline-seed.ps1"'
$opus = '"model": "opus"'
$sonnet = '"model": "sonnet"'
$accs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "compte2"; Dir = ".claude-compte2" })

Use-Pc "MA"
Save-Registry $accs
Set-PcFile $rel (New-SettingsText @($opus, $foreignHooks, $slA)) 1700000000
$r = Invoke-DriveSync
Assert-True $r.Ok ("reglages : envoi reussi " + $r.Error)
Assert-Equal (New-SettingsText @($opus, $canonHooks)) (Get-FakeText $rel) "Drive : sans statusLine, hook sous forme canonique"
Assert-Equal (New-SettingsText @($opus, $foreignHooks, $slA)) (Get-PcText $rel) "envoi : fichier local intact"
Assert-Equal 0 (Invoke-DriveSync).Total "envoi : rien a refaire ensuite"

Use-Pc "MB"
Save-Registry $accs
$r = Invoke-DriveSync
Assert-Equal 1 $r.Down "PC neuf : reglages recus"
Assert-Equal (New-SettingsText @($opus, $localHooks)) (Get-PcText $rel) "PC neuf : aucun statusLine recu, hook adapte au PC"
Set-PcFile $rel (New-SettingsText @($opus, $localHooks, $slB))
Assert-Equal 0 (Invoke-DriveSync).Total "statusLine pose sur ce PC : rien a envoyer"

Use-Pc "MA"
Set-PcFile $rel (New-SettingsText @($sonnet, $localHooks, $slA)) 1700000100
Set-PcFile ".claude-compte2/settings.json" (New-SettingsText @($opus, $slA)) 1700000100
$null = Invoke-DriveSync
Use-Pc "MB"
$r = Invoke-DriveSync
Assert-Equal 2 $r.Down "modification et nouveau compte recus"
Assert-Equal (New-SettingsText @($sonnet, $localHooks, $slB)) (Get-PcText $rel) "modification recue : statusLine de ce PC garde"
Assert-Equal (New-SettingsText @($opus, $slB)) (Get-PcText ".claude-compte2/settings.json") "nouveau compte : statusLine du premier compte de ce PC"
Assert-Equal 0 (Invoke-DriveSync).Total "modification recue : rien a renvoyer"

Add-FakeSealed $rel (Get-FakeEntry $rel).Id (New-SettingsText @($opus, $foreignHooks, $slA)) 1700000200 "ANCIEN"
$r = Invoke-DriveSync
Assert-Equal 1 $r.Down "ancien CLM : reglages bruts recus"
Assert-Equal (New-SettingsText @($opus, $localHooks, $slB)) (Get-PcText $rel) "ancien CLM : statusLine et hook de ce PC gardes"
$r = Invoke-DriveSync
Assert-Equal 1 $r.Up "ancien CLM : Drive nettoye en un envoi"
Assert-Equal (New-SettingsText @($opus, $canonHooks)) (Get-FakeText $rel) "ancien CLM : Drive sans statusLine"
Assert-Equal 0 (Invoke-DriveSync).Total "ancien CLM : stable ensuite"
Restore-FakeDrive
. (Join-Path $bin "drive/core/claude-drive-creds.ps1")
