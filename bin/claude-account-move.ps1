function Move-Account {
  param($Acc, [int]$Rank)
  $list = @(Get-Accounts)
  $from = -1
  for ($i = 0; $i -lt $list.Count; $i++) { if ($list[$i].Dir -eq $Acc.Dir) { $from = $i } }
  if ($from -lt 0) { throw ("compte inconnu : " + $Acc.Label) }
  if ($Rank -lt 1 -or $Rank -gt $list.Count) { throw ("rang " + $Rank + " hors de la liste, de 1 a " + $list.Count) }
  if ($Rank - 1 -eq $from) { return $list[$from].Label + " deja au rang " + $Rank }
  $order = New-Object 'System.Collections.Generic.List[object]'
  foreach ($a in $list) { if ($a.Dir -ne $Acc.Dir) { $order.Add($a) } }
  $order.Insert($Rank - 1, $list[$from])
  Save-Registry $order.ToArray()
  return $list[$from].Label + " passe au rang " + $Rank
}
