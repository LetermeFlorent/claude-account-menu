. Import-ClmModule claude-text
function Move-Account {
  param($Acc, [int]$Rank)
  $list = @(Get-Accounts)
  $from = -1
  for ($i = 0; $i -lt $list.Count; $i++) { if ($list[$i].Dir -eq $Acc.Dir) { $from = $i } }
  if ($from -lt 0) { throw (Get-ClmText "accounts.move.unknown" @($Acc.Label)) }
  if ($Rank -lt 1 -or $Rank -gt $list.Count) { throw (Get-ClmText "accounts.move.outOfRange" @($Rank, $list.Count)) }
  if ($Rank - 1 -eq $from) { return Get-ClmText "accounts.move.alreadyAt" @($list[$from].Label, $Rank) }
  $order = New-Object 'System.Collections.Generic.List[object]'
  foreach ($a in $list) { if ($a.Dir -ne $Acc.Dir) { $order.Add($a) } }
  $order.Insert($Rank - 1, $list[$from])
  Save-Registry $order.ToArray()
  return Get-ClmText "accounts.move.done" @($list[$from].Label, $Rank)
}
