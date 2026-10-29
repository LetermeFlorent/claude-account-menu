param([string]$Bin, [string]$Dir, [string]$Name, [int]$HoldMs, [string]$Then = "", [string]$Text = "")
$ErrorActionPreference = "Stop"
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-machine-lock
$lock = Open-MachineLock $Name
if ($null -eq $lock) { throw "verrou deja pris" }
[IO.File]::WriteAllText((Join-Path $Dir ("held-" + $Name)), "x")
Start-Sleep -Milliseconds $HoldMs
if ($Then) { [IO.File]::WriteAllText($Then, $Text) }
Close-MachineLock $lock
