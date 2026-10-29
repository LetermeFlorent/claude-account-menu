param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-self-update

function Invoke-GitHubGet {
  param([string]$Uri, [int]$Timeout, [string]$OutFile = "")
  $name = "release.json"
  if ($Uri.EndsWith(".zip")) { $name = "clm.zip" } elseif ($Uri.EndsWith(".sha256")) { $name = "clm.zip.sha256" }
  if ($OutFile) { Copy-Item -LiteralPath (Join-Path $Dir $name) -Destination $OutFile; return $null }
  return [PSCustomObject]@{ Content = [IO.File]::ReadAllText((Join-Path $Dir $name)) }
}

Wait-RaceGate $Dir $Id
$restart = Update-Clm
"result " + $Id + " " + $restart + " " + (Get-ClmSha)
