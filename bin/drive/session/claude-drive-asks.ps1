function Get-IncomingAsks {
  param($Pcs, [string]$Me)
  $took = New-PathMap
  if ($null -ne $Pcs[$Me] -and $null -ne $Pcs[$Me].Took) { $took = $Pcs[$Me].Took }
  $list = New-Object 'System.Collections.Generic.List[object]'
  foreach ($from in $Pcs.Keys) {
    if ($from -ceq $Me -or $null -eq $Pcs[$from].Asks) { continue }
    $maps = $Pcs[$from].Asks[$Me]
    if ($null -eq $maps) { continue }
    foreach ($kind in $script:AskKinds) {
      foreach ($n in $maps[$kind].Keys) {
        $a = $maps[$kind][$n]
        if ($a.At -gt [long]$took[$from]) { $list.Add(@{ From = $from; Kind = $kind; Name = $n; On = $a.On; At = $a.At }) }
      }
    }
  }
  return ,@($list | Sort-Object { $_.At })
}

function Use-PcAsk {
  param($Choice, $Ask, $Effective)
  if ($Choice.Erase[$Ask.Kind].Contains($Ask.Name) -or [long]$Choice.Stamps[$Ask.Kind][$Ask.Name] -ge $Ask.At) { return }
  $default = $true
  if ($Ask.Kind -eq "mcp") {
    if ($null -eq $Effective[$Ask.Name]) { return }
    $default = $Effective[$Ask.Name].Os -eq $script:OsName
  }
  Set-ChoiceCheck $Choice $Ask.Kind $Ask.Name $Ask.On $default
  $Choice.Stamps[$Ask.Kind][$Ask.Name] = $Ask.At
}

function Receive-PcAsks {
  param($Prefs)
  $own = Get-OwnPcContent $Prefs.Catalog $Prefs.Pc
  $incomingAsks = Get-IncomingAsks $Prefs.Catalog.Pcs $Prefs.Pc
  if ($incomingAsks.Count -eq 0) { return }
  $askEffective = Get-McpCatalog $Prefs.Catalog.Pcs
  $Prefs.Choice = Update-SyncChoice { param($c) foreach ($a in $incomingAsks) { Use-PcAsk $c $a $askEffective } }
  foreach ($a in $incomingAsks) { if ($a.At -gt [long]$own.Took[$a.From]) { $own.Took[$a.From] = $a.At } }
}

function Remove-StaleAsks {
  param($Choice, $Pcs, [string]$Me, [long]$Old)
  $n = 0
  foreach ($pc in @($Choice.Asks.Keys)) {
    $took = [long]::MaxValue
    if ($null -ne $Pcs[$pc] -and $pc -cne $Me) { $took = [math]::Max($Old, [long]$Pcs[$pc].Took[$Me]) }
    foreach ($kind in $script:AskKinds) {
      $map = $Choice.Asks[$pc][$kind]
      foreach ($k in @($map.Keys)) { if ($map[$k].At -le $took) { $map.Remove($k); $n++ } }
    }
    if (Test-AskMapsEmpty $Choice.Asks[$pc]) { $Choice.Asks.Remove($pc) }
  }
  foreach ($kind in $script:AskKinds) {
    $map = $Choice.Stamps[$kind]
    foreach ($k in @($map.Keys)) { if ($map[$k] -lt $Old) { $map.Remove($k); $n++ } }
  }
  return $n
}

function Update-OwnAsks {
  param($Prefs)
  $askPcs = $Prefs.Catalog.Pcs
  $askMe = $Prefs.Pc
  $askOld = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $script:AskKeepMs
  if ((Remove-StaleAsks (Read-SyncChoice) $askPcs $askMe $askOld) -eq 0) { return }
  $Prefs.Choice = Update-SyncChoice { param($c) $null = Remove-StaleAsks $c $askPcs $askMe $askOld }
}

function Set-OwnPcChoice {
  param($Prefs)
  $own = Get-OwnPcContent $Prefs.Catalog $Prefs.Pc
  $own.Os = $script:OsName
  $own.Choice = @{ skills = $Prefs.Choice.skills; mcp = $Prefs.Choice.mcp }
  $own.Asks = $Prefs.Choice.Asks
  if ($null -eq $own.Took) { $own.Took = New-PathMap }
}
