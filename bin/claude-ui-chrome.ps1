$script:UpArrow = [string][char]0x2191
$script:DownArrow = [string][char]0x2193
$script:MenuFooter = @("Entree", "lancer", "a", "ajouter", "x", "retirer", "n", "renommer", "m", "maj", "y", "sync", "s", "sauvegarder", "r", "restaurer", "q", "quitter")

function Get-HeaderRow {
  param([string]$Title, [int]$W, [string]$Right = "")
  $r = New-Row
  $r.Add(@(("  " + $Title), $script:Ink.Text, $true))
  if ($Right) { Add-RightSegs $r ($W - 2) @(, @($Right, $script:Ink.Dim, $false)) }
  return ,$r
}

function Get-RuleRow {
  param([int]$W, [string]$Tip = "")
  $r = New-Row
  $n = [math]::Max(1, $W - 4 - $Tip.Length)
  $r.Add(@(("  " + ($script:Rule * $n)), $script:Ink.Empty, $false))
  if ($Tip) { $r.Add(@($Tip, $script:Ink.Dim, $true)) }
  return ,$r
}

function Get-FooterRows {
  param([string[]]$Pairs, [int]$W)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $r = New-Row
  $len = 0
  for ($i = 0; $i + 1 -lt $Pairs.Count; $i += 2) {
    $piece = 3 + $Pairs[$i].Length + $Pairs[$i + 1].Length
    if ($len -gt 0 -and $len + $piece -gt $W - 2) { $rows.Add($r); $r = New-Row; $len = 0 }
    $r.Add(@(("  " + $Pairs[$i]), $script:Ink.Text, $false, $Pairs[$i]))
    $r.Add(@((" " + $Pairs[$i + 1]), $script:Ink.Dim, $false, $Pairs[$i]))
    $len += $piece
  }
  $rows.Add($r)
  return ,$rows
}

function Add-PlainRow {
  param($Rows, $Fades, $Row)
  $Rows.Add($Row)
  $Fades.Add(1.0)
}

function Add-MarkSeg {
  param($Row)
  if ($Row.Count -eq 0 -or $Row[0][0].Length -lt 4) { return }
  $first = $Row[0]
  $Row[0] = @(("  " + $script:Mark + " "), $script:Levels["5h"][0], $false)
  if ($first[0].Length -gt 4) { $Row.Insert(1, @($first[0].Substring(4), $first[1], $first[2])) }
}
