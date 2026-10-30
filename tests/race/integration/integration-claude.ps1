$itLog = $env:CLM_ITEST_LOG
$itVerb = "session"
if ($args -contains "update") { $itVerb = "update" }
if ($args -contains "--version") { "2.1.300 (Claude Code)"; exit 0 }
[IO.File]::WriteAllText((Join-Path $itLog ("claude-" + $itVerb + "-" + $PID)), ($env:CLM_ITEST_ID + " " + $env:CLM_ITEST_STARTS + " " + (@($args) -join " ")))
if ($itVerb -eq "update") {
  Start-Sleep -Milliseconds 800
  "Current version: 2.1.300"
  "Claude Code is up to date (2.1.300)"
  exit 0
}
$itGo = Join-Path $itLog "session-end"
$itClock = [Diagnostics.Stopwatch]::StartNew()
while ($env:CLM_ITEST_HOLD -eq "1" -and -not [IO.File]::Exists($itGo) -and $itClock.ElapsedMilliseconds -lt 60000) { Start-Sleep -Milliseconds 50 }
[IO.File]::WriteAllText((Join-Path $itLog ("claude-ended-" + $PID)), [string]$itClock.ElapsedMilliseconds)
exit 0
