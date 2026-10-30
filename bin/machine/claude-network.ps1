$script:NetworkHosts = @("api.anthropic.com", "github.com")
$script:NetworkPort = 443
$script:NetworkTimeoutMs = 3000
$script:NetworkTries = 3
$script:NetworkRetryMs = 200

function Test-NetworkOnce {
  param($Clock)
  $clients = @()
  $tasks = @()
  try {
    foreach ($h in $script:NetworkHosts) {
      $c = New-Object System.Net.Sockets.TcpClient
      $clients += $c
      try { $tasks += $c.ConnectAsync($h, $script:NetworkPort) } catch { continue }
    }
    while ($tasks.Count -gt 0 -and $Clock.ElapsedMilliseconds -lt $script:NetworkTimeoutMs) {
      if (@($tasks | Where-Object { $_.Status -eq "RanToCompletion" }).Count -gt 0) { return $true }
      if (@($tasks | Where-Object { -not $_.IsCompleted }).Count -eq 0) { return $false }
      Start-Sleep -Milliseconds 20
    }
    return $false
  } finally { foreach ($c in $clients) { $c.Close() } }
}

function Test-Network {
  $clock = [Diagnostics.Stopwatch]::StartNew()
  for ($i = 1; $i -le $script:NetworkTries; $i++) {
    if ($i -gt 1) { Start-Sleep -Milliseconds $script:NetworkRetryMs }
    if (Test-NetworkOnce $clock) { return $true }
    if ($clock.ElapsedMilliseconds -ge $script:NetworkTimeoutMs) { return $false }
  }
  return $false
}
