. (Join-Path $bin "ui/terminal/claude-console-clear.ps1")
function Clear-Host { throw "The handle is invalid." }
$clearFailed = $null
try { Clear-ConsoleScreen } catch { $clearFailed = $_.Exception.Message }
Assert-Null $clearFailed "effacer l'ecran : sans console, l'erreur du systeme ne remonte pas"
Remove-Item Function:\Clear-Host
foreach ($clearName in @("claude-menu.ps1", "accounts/claude-account-add.ps1", "menu/manage/claude-menu-rename.ps1")) {
  Assert-True (-not ((Get-Content -LiteralPath (Join-Path $bin $clearName) -Raw) -match "(?m)^\s*Clear-Host\b")) ("effacer l'ecran : " + $clearName + " passe par Clear-ConsoleScreen")
}
Assert-True ((Get-Content -LiteralPath (Join-Path $bin "claude-menu.ps1") -Raw) -match "claude-console-clear") "effacer l'ecran : le menu charge claude-console-clear"
