$script:RaceOldVersion = "1111111111111111111111111111111111111111 1760000000 5"
$script:RaceNewVersion = "2222222222222222222222222222222222222222 1770000000 6"
$script:RaceRelease = '{"tag_name":"v6","published_at":"2026-10-29T08:00:00Z","assets":[{"name":"clm-v6.zip"}]}'

$script:RaceInstallerPs1 = @'
$ErrorActionPreference = "Stop"
$dst = Join-Path (Join-Path $env:USERPROFILE ".local") "bin"
[IO.File]::WriteAllText((Join-Path $env:CLM_RACE_LOG ("install-" + $PID)), "x")
Start-Sleep -Milliseconds 1500
EXTRA
[IO.File]::WriteAllText((Join-Path $dst "clm.version"), "VERSION`n")
'@

$script:RaceInstallerSh = @'
touch "$CLM_RACE_LOG/install-$$"
sleep 2
EXTRA
printf '%s\n' "VERSION" > "$HOME/.local/bin/clm.version"
'@

$script:RaceCopyPs1 = 'Copy-Item -Path (Join-Path (Join-Path $PSScriptRoot "bin") "*") -Destination $dst -Force'
$script:RaceCopySh = 'cp "$(dirname "$0")"/bin/* "$HOME/.local/bin/"'

function New-RaceHome {
  param([string]$Name)
  $root = Join-Path $script:Sandbox $Name
  $target = Join-Path (Join-Path $root ".local") "bin"
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  Copy-Item -Path (Join-Path $bin "*") -Destination $target -Recurse -Force
  [IO.File]::WriteAllText((Join-Path $target "clm.version"), $script:RaceOldVersion + "`n")
  return [PSCustomObject]@{ Root = $root; Bin = $target; Env = @{ USERPROFILE = $root; HOME = $root; LOCALAPPDATA = (Join-Path $root "AppData"); CLM_RACE_LOG = $root } }
}

function New-RaceRelease {
  param([string]$Dir, [hashtable]$Extra = @{})
  $pkg = Join-Path $Dir "pkg"
  New-Item -ItemType Directory -Path (Join-Path $pkg "bin") -Force | Out-Null
  foreach ($k in $Extra.Keys) { [IO.File]::WriteAllText((Join-Path (Join-Path $pkg "bin") $k), $Extra[$k]) }
  $copyPs1 = ""
  $copySh = ""
  if ($Extra.Count -gt 0) { $copyPs1 = $script:RaceCopyPs1; $copySh = $script:RaceCopySh }
  [IO.File]::WriteAllText((Join-Path $pkg "install.ps1"), $script:RaceInstallerPs1.Replace("VERSION", $script:RaceNewVersion).Replace("EXTRA", $copyPs1))
  [IO.File]::WriteAllText((Join-Path $pkg "install.sh"), $script:RaceInstallerSh.Replace("VERSION", $script:RaceNewVersion).Replace("EXTRA", $copySh))
  $zip = Join-Path $Dir "clm.zip"
  Compress-Archive -Path (Join-Path $pkg "*") -DestinationPath $zip
  $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
  [IO.File]::WriteAllText((Join-Path $Dir "clm.zip.sha256"), $hash + "  clm.zip`n")
  [IO.File]::WriteAllText((Join-Path $Dir "release.json"), $script:RaceRelease)
}

function Get-RaceResults {
  param($Runs)
  return (@(foreach ($r in $Runs) { @($r.Out -split "`r?`n" | Where-Object { $_ -like "result *" }) }) -join "|")
}
