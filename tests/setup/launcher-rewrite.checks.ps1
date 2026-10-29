if ($script:OsName -eq "Windows") {
  $lwRoot = Join-Path $script:Sandbox "launcher"
  $lwCounter = 0
  $lwWinPs = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  $lwMenuText = @'
[IO.File]::WriteAllText((Join-Path $PSScriptRoot "host.txt"), [Diagnostics.Process]::GetCurrentProcess().Path + "|" + $env:clm_host)
$ascii = [Text.Encoding]::ASCII
foreach ($name in @("clm.cmd", "claude-menu.cmd")) {
  $file = Join-Path $PSScriptRoot $name
  if (-not (Test-Path -LiteralPath $file)) { continue }
  $size = (Get-Item -LiteralPath $file).Length
  $pad = "rem " + ("x" * ($size - 6)) + "`r`n"
  $tail = 'echo garbage>"%~dp0garbage.txt"' + "`r`n" + "exit /b 0`r`n"
  [IO.File]::WriteAllText($file, $pad + $tail, $ascii)
}
exit 7
'@

  function Invoke-LauncherCopy {
    param([string]$Launcher, [string]$ProgramFilesDir)
    $script:lwCounter++
    $dir = Join-Path $lwRoot ("run" + $script:lwCounter)
    New-Item -ItemType Directory -Path $dir, $ProgramFilesDir -Force | Out-Null
    foreach ($name in @("clm.cmd", "claude-menu.cmd")) { Copy-Item -LiteralPath (Join-Path $bin $name) -Destination (Join-Path $dir $name) }
    [IO.File]::WriteAllText((Join-Path $dir "claude-menu.ps1"), $lwMenuText, (New-Object Text.UTF8Encoding($false)))
    $start = "@echo off`r`nset `"ProgramFiles=" + $ProgramFilesDir + "`"`r`n`"%~dp0" + $Launcher + "`"`r`n"
    [IO.File]::WriteAllText((Join-Path $dir "start.cmd"), $start, [Text.Encoding]::ASCII)
    & cmd.exe /d /c (Join-Path $dir "start.cmd") 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $hostFile = Join-Path $dir "host.txt"
    $hostText = "|"
    if (Test-Path -LiteralPath $hostFile) { $hostText = [IO.File]::ReadAllText($hostFile).Trim() }
    $hostParts = $hostText.Split("|")
    return [pscustomobject]@{ Code = $code; Garbage = (Test-Path -LiteralPath (Join-Path $dir "garbage.txt")); HostPath = $hostParts[0]; Leak = $hostParts[1] }
  }

  $lwEmpty = Join-Path $lwRoot "pf-empty"
  foreach ($lwName in @("clm.cmd", "claude-menu.cmd")) {
    $lwResult = Invoke-LauncherCopy $lwName $lwEmpty
    Assert-Equal 7 $lwResult.Code ($lwName + " : code du menu rendu")
    Assert-True (-not $lwResult.Garbage) ($lwName + " reecrit pendant le menu : rien d'autre lance")
    Assert-Equal "" $lwResult.Leak ($lwName + " : aucune variable du lanceur laissee au menu")
  }
  $lwFallback = Invoke-LauncherCopy "clm.cmd" $lwEmpty
  Assert-Equal $lwWinPs.ToLowerInvariant() $lwFallback.HostPath.ToLowerInvariant() "sans pwsh 7 : powershell windows par chemin absolu"

  $lwSevenRoot = Join-Path $lwRoot "pf-seven"
  $lwSevenDir = Join-Path (Join-Path $lwSevenRoot "PowerShell") "7"
  New-Item -ItemType Directory -Path $lwSevenDir -Force | Out-Null
  $lwSeven = Join-Path $lwSevenDir "pwsh.exe"
  Copy-Item -LiteralPath $lwWinPs -Destination $lwSeven
  $lwPreferred = Invoke-LauncherCopy "clm.cmd" $lwSevenRoot
  Assert-Equal $lwSeven.ToLowerInvariant() $lwPreferred.HostPath.ToLowerInvariant() "pwsh 7 prefere quand il est installe"
}
