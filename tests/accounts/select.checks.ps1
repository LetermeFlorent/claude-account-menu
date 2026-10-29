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
Assert-Equal (Get-ClmText "backup.archive.notFound" @($missing)) $err "restauration d'un fichier absent refusee"
$clearKept = (Get-Item function:Clear-ConsoleInput -ErrorAction SilentlyContinue).ScriptBlock
$script:ChoiceLog = New-Object 'System.Collections.Generic.List[string]'
function Clear-ConsoleInput { $script:ChoiceLog.Add("flush") }
function Read-ChoiceAnswer { param($Prompt) $script:ChoiceLog.Add("prompt"); return $script:ChoiceAnswer }
Set-Alias -Name Read-Host -Value Read-ChoiceAnswer
try {
  $usages = @($accs | ForEach-Object { [PSCustomObject]@{ Acc = $_ } })
  $script:ChoiceAnswer = "2"
  Assert-Equal "Pro" (Read-AccountNumber $usages).Label "liste texte : numero tape apres la question, compte choisi"
  Assert-Equal "flush flush prompt" ($script:ChoiceLog -join " ") "liste texte : console videe avant la question"
  $script:ChoiceAnswer = "4"
  Assert-Null (Read-AccountNumber $usages) "liste texte : numero hors de la liste, aucun compte"
  $script:ChoiceAnswer = ""
  Assert-Null (Read-AccountNumber $usages) "liste texte : Entree seule, aucun compte"
} finally {
  Remove-Item -Path Alias:Read-Host, function:Read-ChoiceAnswer
  if ($clearKept) { Set-Item -Path function:Clear-ConsoleInput -Value $clearKept } else { Remove-Item -Path function:Clear-ConsoleInput }
}
$readKept = (Get-Item function:Read-UiInput -ErrorAction SilentlyContinue).ScriptBlock
function New-FakeKey {
  param([string]$Text)
  if ($Text -eq "`r") { return New-Object System.ConsoleKeyInfo([char]13, [ConsoleKey]::Enter, $false, $false, $false) }
  return New-Object System.ConsoleKeyInfo([char]$Text, [ConsoleKey]("D" + $Text), $false, $false, $false)
}
function Read-FakeUiInput {
  if ($script:FakeBuffer.Count -gt 0) { return $script:FakeBuffer.Dequeue() }
  foreach ($k in $script:FakeLate) { $script:FakeBuffer.Enqueue($k) }
  $script:FakeLate.Clear()
  return $null
}
function Wait-FakeSettle {
  param($Milliseconds)
  $script:FakeSleeps.Add($Milliseconds)
}
function Read-FakeLine {
  param($Prompt)
  $line = ""
  while ($script:FakeBuffer.Count -gt 0) {
    $k = $script:FakeBuffer.Dequeue()
    if ($k.Key -eq [ConsoleKey]::Enter) { break }
    $line += $k.KeyChar
  }
  return $line + $script:FakeTyped
}
function Start-FakeConsole {
  param($Buffered, $Late, [string]$Typed)
  $script:FakeBuffer = New-Object 'System.Collections.Generic.Queue[object]'
  $script:FakeLate = New-Object 'System.Collections.Generic.List[object]'
  $script:FakeSleeps = New-Object 'System.Collections.Generic.List[object]'
  foreach ($t in $Buffered) { $script:FakeBuffer.Enqueue((New-FakeKey $t)) }
  foreach ($t in $Late) { $script:FakeLate.Add((New-FakeKey $t)) }
  $script:FakeTyped = $Typed
}
Set-Item -Path function:Read-UiInput -Value (Get-Item function:Read-FakeUiInput).ScriptBlock
Set-Alias -Name Start-Sleep -Value Wait-FakeSettle
Set-Alias -Name Read-Host -Value Read-FakeLine
try {
  $usages = @($accs | ForEach-Object { [PSCustomObject]@{ Acc = $_ } })
  Start-FakeConsole @("1", "`r") @() ""
  Assert-Null (Read-AccountNumber $usages) "liste texte : ligne deja dans la console avant la question, jamais un choix"
  Start-FakeConsole @() @("2", "`r") ""
  Assert-Null (Read-AccountNumber $usages) "liste texte : ligne arrivee pendant la pause, jamais un choix"
  Start-FakeConsole @() @() "2"
  Assert-Equal "Pro" (Read-AccountNumber $usages).Label "liste texte : numero tape apres la question, vrai vidage, compte choisi"
  Start-FakeConsole @() @() ""
  Assert-Null (Read-AccountNumber $usages) "liste texte : ligne vide tapee apres la question, aucun compte"
  Start-FakeConsole @() @() ""
  $null = Read-AccountNumber $usages
  $settle = if ($script:FakeSleeps.Count -gt 0) { $script:FakeSleeps[0] } else { -1 }
  Assert-Equal $script:InputSettleMs $settle "liste texte : pause de stabilisation de InputSettleMs millisecondes"
} finally {
  Remove-Item -Path Alias:Start-Sleep, Alias:Read-Host, function:New-FakeKey, function:Read-FakeUiInput, function:Wait-FakeSettle, function:Read-FakeLine, function:Start-FakeConsole
  if ($readKept) { Set-Item -Path function:Read-UiInput -Value $readKept } else { Remove-Item -Path function:Read-UiInput }
}
