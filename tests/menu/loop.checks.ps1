. (Join-Path $bin "claude-menu-loop.ps1")

$mocked = @("Enter-UiScreen", "Exit-UiScreen", "Hide-Screen", "Show-Menu", "Start-MenuLoader", "Get-Accounts", "Update-UiTick", "New-ClmCheck")
$kept = @{}
foreach ($n in $mocked) { $kept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
function Enter-UiScreen { $script:UiOn = $true }
function Exit-UiScreen { $script:UiOn = $false }
function Hide-Screen {}
function Show-Menu { param($State, [double]$Now) $State.Dirty = $false }
function Start-MenuLoader { param($State) }
function Get-Accounts { return @(foreach ($l in @("a", "b", "c")) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } }) }
function Update-UiTick { param([double]$Now, [bool]$Busy) return $false }
$script:FakeLatest = $null
function New-ClmCheck { return @{ Loader = $null; NextAt = $null; Installed = $null; Latest = $script:FakeLatest } }

function Invoke-WithKeys {
  param([object[]]$Keys)
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
  foreach ($k in $Keys) {
    $c = [char]0
    if ($k -is [string]) { $c = [char]$k; $k = [ConsoleKey]::D2 }
    $script:UiKeys.Enqueue((New-Object System.ConsoleKeyInfo $c, $k, $false, $false, $false))
  }
  return Invoke-AccountMenu $false
}

try {
  Assert-Equal "b" (Invoke-WithKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Enter)).Label "fleche bas puis Entree"
  Assert-Equal "c" (Invoke-WithKeys @([ConsoleKey]::UpArrow, [ConsoleKey]::Enter)).Label "fleche haut fait le tour"
  Assert-Equal "b" (Invoke-WithKeys @("2")).Label "chiffre lance le compte"
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::Escape)) "Echap quitte"
  Assert-Null (Invoke-WithKeys @([string][char]3)) "Ctrl+C quitte"
  Assert-True (-not $script:UiOn) "ecran rendu en sortie"
  Assert-Null (Invoke-WithKeys @("u", [ConsoleKey]::Escape)) "u sans nouvelle version, menu garde"
  Assert-True (-not $script:MenuRestart) "u sans nouvelle version, pas de redemarrage"
  $script:FakeLatest = [PSCustomObject]@{ Sha = ("b" * 40); Time = 2; Number = 0 }
  Assert-Null (Invoke-WithKeys @("u")) "u avec nouvelle version, menu ferme"
  Assert-True $script:MenuRestart "u avec nouvelle version, redemarrage demande"
} finally {
  foreach ($n in $mocked) { Set-Item -Path ("function:" + $n) -Value $kept[$n] }
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
}
