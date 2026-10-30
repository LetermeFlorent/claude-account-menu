. Import-ClmModule claude-self-copy
$copySha = "abcdef1234567890abcdef1234567890abcdef12"
$copyVersion = $copySha + " 1770000000 7"
$copyMove = (Get-Item "function:Move-FileOver").ScriptBlock

function New-CopyTree {
  param([string]$Name, [hashtable]$Files)
  $root = Join-Path $script:Sandbox $Name
  foreach ($rel in $Files.Keys) { $null = New-SandboxFile ($Name + "/" + $rel) $Files[$rel] }
  return $root
}

function Get-CopyText {
  param([string]$Root, [string]$Rel)
  $p = [IO.Path]::Combine($Root, $Rel)
  if (-not [IO.File]::Exists($p)) { return "<absent>" }
  return [IO.File]::ReadAllText($p)
}

function Get-CopyLeftovers {
  param([string]$Root)
  return @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object { $_.Name -like "*.tmp" -or $_.Name -eq "clm.installing" }).Count
}

$copyV1 = @{ "claude-a.ps1" = "a1"; "claude-b.ps1" = "b1"; "clm.cmd" = "cmd1"; "clm" = "sh1"; "clm-web/app.js" = "js1"; "clm-web/deep/x.json" = "x1"; "lang/fr.json" = "fr1" }
$copySrc = New-CopyTree "copy-src1" $copyV1
$copyDst = Join-Path $script:Sandbox "copy-dst"
$null = New-SandboxFile "copy-dst/other-tool.exe" "tiers"
$null = New-SandboxFile "copy-dst/foreign/keep.txt" "tiers"
$null = New-SandboxFile "copy-dst/clm-web/stale.js" "vieux"
Install-ClmFiles $copySrc $copyDst $copyVersion @("clm")
Assert-Equal "a1|b1|cmd1|js1|x1|fr1|<absent>" ((@("claude-a.ps1", "claude-b.ps1", "clm.cmd", "clm-web/app.js", "clm-web/deep/x.json", "lang/fr.json", "clm") | ForEach-Object { Get-CopyText $copyDst $_ }) -join "|") "installation : arbre copie avec ses sous-dossiers, lanceur sh ecarte"
Assert-Equal ($copyVersion + "`n") (Get-CopyText $copyDst "clm.version") "installation : version ecrite"
Assert-Equal "claude-a.ps1`nclaude-b.ps1`nclm-web/app.js`nclm-web/deep/x.json`nclm.cmd`nlang/fr.json`n" (Get-CopyText $copyDst "clm.files") "installation : liste des fichiers installes"
Assert-Equal "<absent>|tiers|tiers" ((Get-CopyText $copyDst "clm-web/stale.js"), (Get-CopyText $copyDst "other-tool.exe"), (Get-CopyText $copyDst "foreign/keep.txt") -join "|") "installation : vieux fichier d'un sous-dossier de clm retire, fichiers d'autres outils gardes"
Assert-Equal 0 (Get-CopyLeftovers $copyDst) "installation : ni temporaire ni marqueur laisse"

$copyOld = [DateTime]::UtcNow.AddDays(-30)
[IO.File]::SetLastWriteTimeUtc((Join-Path $copyDst "claude-a.ps1"), $copyOld)
$copyV2 = @{ "claude-a.ps1" = "a1"; "claude-b.ps1" = "b2"; "claude-c.ps1" = "c2"; "clm-web/app.js" = "js2"; "lang/fr.json" = "fr1" }
$copySrc2 = New-CopyTree "copy-src2" $copyV2
Install-ClmFiles $copySrc2 $copyDst ($copySha + " 1770000100 8")
Assert-Equal $copyOld.ToString("o") ([IO.File]::GetLastWriteTimeUtc((Join-Path $copyDst "claude-a.ps1")).ToString("o")) "mise a jour : fichier identique laisse tel quel"
Assert-Equal "b2|c2|js2" ((Get-CopyText $copyDst "claude-b.ps1"), (Get-CopyText $copyDst "claude-c.ps1"), (Get-CopyText $copyDst "clm-web/app.js") -join "|") "mise a jour : fichiers changes et nouveaux poses"
Assert-Equal "<absent>|<absent>|False" ((Get-CopyText $copyDst "clm.cmd"), (Get-CopyText $copyDst "clm-web/deep/x.json"), [IO.Directory]::Exists((Join-Path $copyDst "clm-web/deep")) -join "|") "mise a jour : fichiers que la version ne livre plus retires, dossier vide retire"
Assert-Equal "tiers|tiers" ((Get-CopyText $copyDst "other-tool.exe"), (Get-CopyText $copyDst "foreign/keep.txt") -join "|") "mise a jour : fichiers d'autres outils gardes"

$script:CopyMoves = New-Object Collections.Generic.List[string]
function Move-FileOver {
  param([string]$From, [string]$To)
  $marked = [IO.File]::Exists((Join-Path $copyDst "clm.installing"))
  $script:CopyMoves.Add([IO.Path]::GetFileName($To) + "=" + $marked)
  & $copyMove $From $To
}
$copyV3 = @{ "claude-a.ps1" = "a3"; "claude-new.ps1" = "n3"; "lang/fr.json" = "fr1" }
$copySrc3 = New-CopyTree "copy-src3" $copyV3
try { Install-ClmFiles $copySrc3 $copyDst ($copySha + " 1770000200 9") } finally { Set-Item "function:Move-FileOver" $copyMove }
Assert-Equal "claude-new.ps1=True|claude-a.ps1=True|clm.files=True|clm.version=True" ($script:CopyMoves -join "|") "ordre : marqueur d'abord, nouveaux fichiers, puis changes, liste, et version en dernier"
Assert-Equal "<absent>|<absent>" ((Get-CopyText $copyDst "claude-b.ps1"), (Get-CopyText $copyDst "clm-web/app.js") -join "|") "ordre : fichiers retires de la version precedente"
Assert-Equal "False" ([IO.Directory]::Exists((Join-Path $copyDst "clm-web"))) "ordre : sous-dossier qui n'est plus livre retire"

function Move-FileOver {
  param([string]$From, [string]$To)
  if ($To.EndsWith("claude-a.ps1")) { throw "disque plein" }
  & $copyMove $From $To
}
$copyV4 = @{ "claude-a.ps1" = "a4"; "claude-new.ps1" = "n4" }
$copySrc4 = New-CopyTree "copy-src4" $copyV4
$copyVersion3 = Get-CopyText $copyDst "clm.version"
try { Assert-Throws { Install-ClmFiles $copySrc4 $copyDst ($copySha + " 1770000300 10") } "disque plein" "echec : erreur remontee" } finally { Set-Item "function:Move-FileOver" $copyMove }
Assert-Equal 0 (Get-CopyLeftovers $copyDst) "echec : marqueur retire, aucun temporaire"
Assert-Equal $copyVersion3 (Get-CopyText $copyDst "clm.version") "echec : ancienne version gardee"

Install-ClmFiles $copySrc4 $copyDst ""
Assert-Equal "<absent>|a4" ((Get-CopyText $copyDst "clm.version"), (Get-CopyText $copyDst "claude-a.ps1") -join "|") "sans version : fichiers poses, fichier de version retire"
