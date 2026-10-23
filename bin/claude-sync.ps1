if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
$script:AccountKeys = @("model", "modelSettings", "theme")
$script:SyncStatePath = Get-StatePath "sync-state.json"
$script:SyncLockPath = Get-StatePath "sync.lock"

function Invoke-WithSyncLock {
  param([scriptblock]$Action)
  $deadline = (Get-Date).AddSeconds(5)
  while ($true) {
    try { $fs = [IO.File]::Open($script:SyncLockPath, "OpenOrCreate", "ReadWrite", "None"); break }
    catch {
      if ((Get-Date) -gt $deadline) { Write-Host "  sync ignoree : un autre lancement synchronise deja" -ForegroundColor DarkYellow; return }
      Start-Sleep -Milliseconds 200
    }
  }
  try { & $Action } finally { $fs.Dispose() }
}

function Get-SharedSettings {
  param($Data)
  $shared = [ordered]@{}
  foreach ($k in $Data.Keys) { if ($script:AccountKeys -notcontains $k) { $shared[$k] = $Data[$k] } }
  return $shared
}

function Merge-Settings {
  param($Data, $Shared)
  $merged = [ordered]@{}
  foreach ($k in $Shared.Keys) { $merged[$k] = $Shared[$k] }
  foreach ($k in $script:AccountKeys) { if ($Data.Keys -contains $k) { $merged[$k] = $Data[$k] } }
  return $merged
}

function Get-McpServers {
  param($Data)
  if ($Data.Keys -contains "mcpServers") { return $Data["mcpServers"] }
  return [ordered]@{}
}

function Merge-Mcp {
  param($Data, $Shared)
  $Data["mcpServers"] = $Shared
  return $Data
}

function Sync-Domain {
  param([string]$Name, [string[]]$Paths, [scriptblock]$GetShared, [scriptblock]$Merge, $State)
  $items = foreach ($p in $Paths) {
    $data = Read-JsonFile $p
    if ($null -eq $data) { continue }
    $shared = & $GetShared $data
    [PSCustomObject]@{ Path = $p; Data = $data; Shared = $shared; Text = (ConvertTo-JsonText $shared); Time = [IO.File]::GetLastWriteTimeUtc($p) }
  }
  $items = @($items)
  $base = $null
  if ($State.Keys -contains $Name) { $base = $State[$Name] }
  $changed = @($items | Where-Object { $_.Text -ne $base })
  if ($changed.Count -eq 0) { return }
  $winner = @($changed | Sort-Object Time -Descending)[0]
  foreach ($it in $items) {
    if ($it.Text -ne $winner.Text) { Write-JsonFile $it.Path (& $Merge $it.Data $winner.Shared) }
  }
  $State[$Name] = $winner.Text
}

function Sync-Accounts {
  Invoke-WithSyncLock {
    try {
      $accs = @(Get-Accounts)
      foreach ($a in $accs) { Repair-SharedLinks $a }
      $state = Read-JsonFile $script:SyncStatePath
      if ($null -eq $state) { $state = [ordered]@{} }
      $settings = @($accs | ForEach-Object { Join-Path (Get-AccountPath $_) "settings.json" })
      $configs = @($accs | ForEach-Object { Get-AccountConfigFile $_ })
      Sync-Domain "settings" $settings ${function:Get-SharedSettings} ${function:Merge-Settings} $state
      Sync-Domain "mcpServers" $configs ${function:Get-McpServers} ${function:Merge-Mcp} $state
      [IO.File]::WriteAllText($script:SyncStatePath, (ConvertTo-JsonText $state), (New-Object Text.UTF8Encoding $false))
    } catch {
      Write-Host ("  sync echouee : " + $_.Exception.Message) -ForegroundColor DarkYellow
    }
  }
}
