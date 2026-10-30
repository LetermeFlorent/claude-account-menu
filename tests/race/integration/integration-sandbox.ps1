. Import-ClmModule claude-self-copy, claude-state
$script:ItestOld = "1111111111111111111111111111111111111111 1760000000 5"
$script:ItestNew = "2222222222222222222222222222222222222222 1770000000 6"
$script:ItestRelease = '{"tag_name":"v6","published_at":"2026-10-29T08:00:00Z","assets":[{"name":"clm-v6.zip"}]}'
$script:ItestCurrent = '{"tag_name":"v5","published_at":"2025-10-09T08:00:00Z","assets":[{"name":"clm-v5.zip"}]}'
$script:ItestAccounts = @(".claude", ".claude-compte2", ".claude-compte3")

$script:ItestInstaller = @'
$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "bin"
$dst = Join-Path (Join-Path $env:HOME ".local") "bin"
[IO.File]::WriteAllText((Join-Path $env:CLM_ITEST_LOG ("install-" + $PID)), "x")
. (Join-Path $src "claude-import.ps1")
. Import-ClmModule claude-self-copy
Install-ClmFiles $src $dst "VERSION" @("clm")
'@

function New-ItestDirs {
  param([string]$Root)
  $h = Join-Path $Root "home"
  $dirs = [ordered]@{ Root = $Root; Home = $h; Bin = (Join-Path (Join-Path $h ".local") "bin"); Log = (Join-Path $Root "log"); Release = (Join-Path $Root "release"); Fake = (Join-Path $Root "fakebin"); Tmp = (Join-Path $Root "tmp"); Drive = (Join-Path $Root "drive"); Gate = (Join-Path $Root "gate") }
  foreach ($d in $dirs.Values) { $null = [IO.Directory]::CreateDirectory($d) }
  foreach ($a in $script:ItestAccounts) { $null = [IO.Directory]::CreateDirectory((Join-Path $h $a)); [IO.File]::WriteAllText((Join-Path (Join-Path $h $a) "settings.json"), "{}`n") }
  return [PSCustomObject]$dirs
}

function New-ItestEnv {
  param($Box)
  $h = $Box.Home
  $vars = @{ HOME = $h; USERPROFILE = $h; LOCALAPPDATA = (Join-Path (Join-Path $h "AppData") "Local"); APPDATA = (Join-Path (Join-Path $h "AppData") "Roaming"); TEMP = $Box.Tmp; TMP = $Box.Tmp; TMPDIR = $Box.Tmp }
  foreach ($x in @("CACHE", "STATE", "CONFIG", "DATA")) { $vars["XDG_" + $x + "_HOME"] = Join-Path (Join-Path $h "xdg") $x.ToLowerInvariant() }
  foreach ($k in @("CLAUDE_CONFIG_DIR", "CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "NoDefaultCurrentDirectoryInExePath", "CLM_RELOADED", "CLM_LANG", "NO_COLOR")) { $vars[$k] = $null }
  $vars["PATH"] = $Box.Fake + [IO.Path]::PathSeparator + $env:PATH
  $vars["CLM_ITEST_LOG"] = $Box.Log
  $vars["CLM_ITEST_RELEASE"] = $Box.Release
  $vars["CLM_ITEST_DRIVE"] = $Box.Drive
  $vars["CLM_ITEST_GATE"] = $Box.Gate
  $vars["STATUSLINE_BG"] = "dark"
  $vars["CLM_ANIM"] = "0"
  $vars["TERM"] = "xterm-256color"
  foreach ($k in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY")) { $vars[$k] = "http://127.0.0.1:9" }
  $vars["NO_PROXY"] = $null
  return $vars
}

function New-ItestClaude {
  param($Box)
  $body = Join-Path $PSScriptRoot "integration-claude.ps1"
  $exe = (Get-Process -Id $PID).Path
  if ($script:OsName -eq "Windows") {
    [IO.File]::WriteAllText((Join-Path $Box.Fake "claude.cmd"), "@`"" + $exe + "`" -NoProfile -ExecutionPolicy Bypass -File `"" + $body + "`" %*`r`n")
    return
  }
  $path = Join-Path $Box.Fake "claude"
  [IO.File]::WriteAllText($path, "#!/bin/sh`nexec '" + $exe + "' -NoProfile -File '" + $body + "' `"`$@`"`n")
  & /bin/chmod 755 $path
}

function New-ItestZip {
  param([string]$Dir)
  $pkg = Join-Path $Dir "pkg"
  $null = Install-ClmFiles $bin (Join-Path $pkg "bin") ""
  [IO.File]::WriteAllText((Join-Path $pkg "install.ps1"), $script:ItestInstaller.Replace("VERSION", $script:ItestNew))
  [IO.File]::WriteAllText((Join-Path $pkg "install.sh"), "exec `"`$CLM_PWSH`" -NoProfile -File `"`$(dirname `"`$0`")/install.ps1`"`n")
  $zip = Join-Path $Dir "clm.zip"
  Compress-Archive -Path (Join-Path $pkg "*") -DestinationPath $zip
  $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
  [IO.File]::WriteAllText((Join-Path $Dir "clm.zip.sha256"), $hash + "  clm.zip`n")
  Remove-Item -LiteralPath $pkg -Recurse -Force
}

function New-ItestRelease {
  param($Box)
  $shared = Join-Path $script:Sandbox "itest-release"
  if (-not [IO.File]::Exists((Join-Path $shared "clm.zip.sha256"))) { New-ItestZip $shared }
  foreach ($name in @("clm.zip", "clm.zip.sha256")) { Copy-Item -LiteralPath (Join-Path $shared $name) -Destination (Join-Path $Box.Release $name) }
}

function Set-ItestRelease {
  param($Box, [bool]$Newer)
  $text = $script:ItestCurrent
  if ($Newer) { $text = $script:ItestRelease }
  [IO.File]::WriteAllText((Join-Path $Box.Release "release.json"), $text)
}

function New-ItestSandbox {
  param([string]$Name, [bool]$Newer)
  $box = New-ItestDirs (Join-Path $script:Sandbox $Name)
  $null = Install-ClmFiles $bin $box.Bin $script:ItestOld @("clm")
  New-ItestClaude $box
  New-ItestRelease $box
  Set-ItestRelease $box $Newer
  Add-Member -InputObject $box -NotePropertyName Env -NotePropertyValue (New-ItestEnv $box)
  Add-Member -InputObject $box -NotePropertyName State -NotePropertyValue (Get-StateDir -Vars $box.Env)
  [IO.File]::WriteAllText((Join-Path $box.State "drive.json"), "{`"pc`": `"PCA`", `"refreshToken`": `"r`"}`n")
  return $box
}
