$selfMocked = @("Invoke-GitHubGet", "Invoke-ClmProcess", "Test-ClmInstalledHere", "Read-ClmVersion")
$selfKept = @{}
foreach ($n in $selfMocked) { $f = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue; if ($f) { $selfKept[$n] = $f.ScriptBlock } }

function Restore-SelfFakes {
  foreach ($n in $selfMocked) {
    if ($selfKept[$n]) { Set-Item -Path ("function:script:" + $n) -Value $selfKept[$n] }
    else { Remove-Item -Path ("function:script:" + $n) -ErrorAction SilentlyContinue }
  }
}

function New-TestRelease {
  param([int]$Number)
  return '{"url":"https://api.github.com/x","tag_name":"v' + $Number + '","target_commitish":"main","name":"clm v' + $Number + '","draft":false,"prerelease":false,"created_at":"2026-10-27T10:00:00Z","published_at":"2026-10-28T08:33:20Z","assets":[{"name":"clm-v' + $Number + '.zip","created_at":"2026-10-27T11:00:00Z"}]}'
}

function New-TestPackage {
  param([string]$Name)
  $pkg = Join-Path $script:Sandbox ($Name + "-pkg")
  New-Item -ItemType Directory -Path (Join-Path $pkg "bin") -Force | Out-Null
  foreach ($f in @("install.ps1", "install.sh", (Join-Path "bin" "clm"))) { [IO.File]::WriteAllText((Join-Path $pkg $f), "exit 0`n") }
  $zip = Join-Path $script:Sandbox ($Name + ".zip")
  Compress-Archive -Path (Join-Path $pkg "*") -DestinationPath $zip
  return $zip
}

function Set-SelfNetwork {
  param([string]$Zip, [string]$Sum, $Release)
  $script:SelfZip = $Zip
  $script:SelfSum = $Sum
  $script:SelfRelease = $Release
  $script:SelfGets = New-Object Collections.Generic.List[string]
  $script:SelfRuns = New-Object Collections.Generic.List[object]
  $script:SelfCode = 0
}

function Invoke-GitHubGet {
  param([string]$Uri, [int]$Timeout, [string]$OutFile = "")
  $script:SelfGets.Add($Uri + " " + $Timeout)
  if ($null -eq $script:SelfRelease) { throw "reseau coupe" }
  if ($Uri.EndsWith(".zip")) { Copy-Item -LiteralPath $script:SelfZip -Destination $OutFile; return $null }
  if ($Uri.EndsWith(".sha256")) { [IO.File]::WriteAllText($OutFile, $script:SelfSum); return $null }
  return [PSCustomObject]@{ Content = $script:SelfRelease }
}

function Invoke-ClmProcess {
  param([string]$Exe, [string[]]$Arguments)
  $script:SelfRuns.Add([PSCustomObject]@{ Exe = $Exe; Arguments = $Arguments; Found = (Test-Path -LiteralPath $Arguments[-1]) })
  return @{ Code = $script:SelfCode; Last = "erreur de copie" }
}

function Test-ClmInstalledHere { return $true }

function Read-ClmVersion {
  param([string]$Dir = "")
  return $script:SelfInstalled
}
