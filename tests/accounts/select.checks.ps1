. (Join-Path $bin "claude-menu-select.ps1")

$accs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" }, [PSCustomObject]@{ Label = "perso"; Dir = ".claude-compte3" })
Assert-Equal "compte1|Pro|perso" ((@(Select-ByLabel $accs "") | ForEach-Object { $_.Label }) -join "|") "selection vide : tous les comptes"
Assert-Equal "Pro|perso" ((@(Select-ByLabel $accs " perso, pro ") | ForEach-Object { $_.Label }) -join "|") "selection par nom, casse et espaces ignores"
$err = $null
try { $null = Select-ByLabel $accs "pro,prso" } catch { $err = $_.Exception.Message }
Assert-Equal "compte inconnu : prso" $err "nom mal tape refuse"
$err = $null
$missing = Join-Path $script:Sandbox "absent.zip"
try { Assert-ArchiveReadable $missing } catch { $err = $_.Exception.Message }
Assert-Equal ("sauvegarde introuvable : " + $missing) $err "restauration d'un fichier absent refusee"
$clearKept = Get-Item function:Clear-ConsoleInput -ErrorAction SilentlyContinue
$script:ChoiceLog = New-Object 'System.Collections.Generic.List[string]'
function Clear-ConsoleInput { $script:ChoiceLog.Add("flush") }
function Read-Host { param($Prompt) $script:ChoiceLog.Add("prompt"); return $script:ChoiceAnswer }
try {
  $usages = @($accs | ForEach-Object { [PSCustomObject]@{ Acc = $_ } })
  $script:ChoiceAnswer = "2"
  Assert-Equal "Pro" (Read-AccountNumber $usages).Label "liste texte : numero tape apres la question, compte choisi"
  Assert-Equal "flush prompt" ($script:ChoiceLog -join " ") "liste texte : console videe avant la question"
  $script:ChoiceAnswer = "4"
  Assert-Null (Read-AccountNumber $usages) "liste texte : numero hors de la liste, aucun compte"
  $script:ChoiceAnswer = ""
  Assert-Null (Read-AccountNumber $usages) "liste texte : Entree seule, aucun compte"
} finally {
  Remove-Item -Path function:Read-Host
  if ($clearKept) { Set-Item -Path function:Clear-ConsoleInput -Value $clearKept.ScriptBlock } else { Remove-Item -Path function:Clear-ConsoleInput }
}
