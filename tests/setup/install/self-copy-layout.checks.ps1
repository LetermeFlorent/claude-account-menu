. Import-ClmModule claude-self-copy
$layoutVersion = "abcdef1234567890abcdef1234567890abcdef12 1770000200 9"
$layoutNew = @{ "claude-menu.ps1" = "m2"; "claude-import.ps1" = "i2"; "clm.cmd" = "c2"; "clm" = "sh2"; "drive/claude-drive-api.ps1" = "d2"; "ui/claude-ui-term.ps1" = "u2"; "lang/fr.json" = "f2" }
$layoutOld = @{ "claude-menu.ps1" = "m1"; "claude-import.ps1" = "i1"; "claude-drive-api.ps1" = "d1"; "claude-ui-term.ps1" = "u1"; "lang/fr.json" = "f1" }
$layoutForeign = @{ "other-tool.exe" = "tiers"; "claude-notes.txt" = "tiers"; "claude-mine.ps1" = "tiers"; "ui/foreign.txt" = "tiers"; "drive/notes.md" = "tiers" }
$layoutSrc = Join-Path $script:Sandbox "layout-src"
foreach ($rel in $layoutNew.Keys) { $null = New-SandboxFile ("layout-src/" + $rel) $layoutNew[$rel] }
$layoutShipped = [string[]]@($layoutNew.Keys | Where-Object { $_ -ne "clm" })
[Array]::Sort($layoutShipped, [StringComparer]::Ordinal)

function Get-LayoutText {
  param([string]$Root, [string[]]$Rels)
  return (@(foreach ($rel in $Rels) {
    $p = [IO.Path]::Combine($Root, $rel)
    if ([IO.File]::Exists($p)) { [IO.File]::ReadAllText($p) } else { "<absent>" }
  }) -join "|")
}

foreach ($case in @("manifeste", "sans manifeste")) {
  $name = "layout-dst-" + $case.Replace(" ", "-")
  $dst = Join-Path $script:Sandbox $name
  foreach ($rel in $layoutOld.Keys) { $null = New-SandboxFile ($name + "/" + $rel) $layoutOld[$rel] }
  foreach ($rel in $layoutForeign.Keys) { $null = New-SandboxFile ($name + "/" + $rel) $layoutForeign[$rel] }
  if ($case -eq "manifeste") { $null = New-SandboxFile ($name + "/clm.files") ((@($layoutOld.Keys | Sort-Object) -join "`n") + "`n") }
  Install-ClmFiles $layoutSrc $dst $layoutVersion @("clm")
  Assert-Equal "m2|i2|c2|d2|u2|f2|<absent>" (Get-LayoutText $dst @("claude-menu.ps1", "claude-import.ps1", "clm.cmd", "drive/claude-drive-api.ps1", "ui/claude-ui-term.ps1", "lang/fr.json", "clm")) ("ancienne installation a plat, " + $case + " : nouvel arbre pose, points d'entree a la racine")
  Assert-Equal "<absent>|<absent>" (Get-LayoutText $dst @("claude-drive-api.ps1", "claude-ui-term.ps1")) ("ancienne installation a plat, " + $case + " : anciens fichiers a plat retires")
  Assert-Equal "tiers|tiers|tiers|tiers|tiers" (Get-LayoutText $dst @($layoutForeign.Keys | Sort-Object)) ("ancienne installation a plat, " + $case + " : fichiers de l'utilisateur gardes")
  Assert-Equal (($layoutShipped -join "`n") + "`n") (Get-LayoutText $dst @("clm.files")) ("ancienne installation a plat, " + $case + " : liste des fichiers du nouvel arbre")
}
$blockedDst = Join-Path $script:Sandbox "layout-dst-blocked"
foreach ($rel in $layoutOld.Keys) { $null = New-SandboxFile ("layout-dst-blocked/" + $rel) $layoutOld[$rel] }
$null = New-SandboxFile "layout-dst-blocked/drive" "tiers"
$blockedFile = Join-Path $blockedDst "drive"
Assert-Throws { Install-ClmFiles $layoutSrc $blockedDst $layoutVersion @("clm") } (Get-ClmText "install.folderBlocked" @($blockedFile)) "fichier de l'utilisateur au nom d'un dossier livre : installation refusee, fichier nomme"
Assert-Equal "m1|d1|tiers|<absent>|<absent>" (Get-LayoutText $blockedDst @("claude-menu.ps1", "claude-drive-api.ps1", "drive", "ui/claude-ui-term.ps1", "clm.installing")) "fichier de l'utilisateur au nom d'un dossier livre : rien copie ni retire avant le refus"
