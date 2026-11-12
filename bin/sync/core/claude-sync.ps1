. Import-ClmModule claude-json, claude-state, claude-drive-lock, claude-text, claude-sessions-sync
$script:AccountKeys = @("model", "modelSettings", "theme")
$script:SyncStatePath = Get-StatePath "sync-state.json"
$script:SyncLockWaitMs = 5000

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
  if (@($items | Where-Object { $_.Text -ne $base }).Count -eq 0) { return }
  $union = Get-UnionShared $items $base
  $text = ConvertTo-JsonText $union
  foreach ($it in $items) {
    if ($it.Text -ne $text) { Write-JsonFile $it.Path (& $Merge $it.Data $union) }
  }
  $State[$Name] = $text
}

function Get-UnionShared {
  param($Items, [string]$BaseText)
  $base = $null
  if ($BaseText) { try { $base = ConvertFrom-JsonText $BaseText } catch { $base = $null } }
  $newest = @($Items | Sort-Object Time -Descending)
  $out = [ordered]@{}
  foreach ($it in $newest) {
    foreach ($k in @($it.Shared.Keys)) {
      if ($out.Contains($k)) { continue }
      $was = $null
      if ($null -ne $base -and @($base.Keys) -contains $k) { $was = ConvertTo-JsonText $base[$k] }
      $pick = @($newest | Where-Object { @($_.Shared.Keys) -contains $k -and (ConvertTo-JsonText $_.Shared[$k]) -ne $was })
      if ($pick.Count -gt 0) { $out[$k] = $pick[0].Shared[$k] } else { $out[$k] = $it.Shared[$k] }
    }
  }
  return $out
}

function Sync-Accounts {
  $null = Invoke-MachineOnce $script:AccountsSyncLock $script:SyncLockWaitMs {
    try {
      $accs = @(Get-Accounts)
      foreach ($a in $accs) { Repair-SharedLinks $a }
      $state = Read-JsonFile $script:SyncStatePath
      if ($null -eq $state) { $state = [ordered]@{} }
      $settings = @($accs | ForEach-Object { Join-Path (Get-AccountPath $_) "settings.json" })
      $configs = @($accs | ForEach-Object { Get-AccountConfigFile $_ })
      Sync-Domain "settings" $settings ${function:Get-SharedSettings} ${function:Merge-Settings} $state
      Sync-Domain "mcpServers" $configs ${function:Get-McpServers} ${function:Merge-Mcp} $state
      if (Test-SessionSyncOn) { $null = Sync-AccountSessions $accs }
      Write-TextFileAtomic $script:SyncStatePath (ConvertTo-JsonText $state)
      $true
    } catch {
      Write-Host ("  " + (Get-ClmText "sync.run.failed" @($_.Exception.Message))) -ForegroundColor DarkYellow
    }
  }
}
