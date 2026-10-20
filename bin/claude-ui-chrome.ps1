$script:UpArrow = [string][char]0x2191
$script:DownArrow = [string][char]0x2193
$script:FrameSide = 0x2502
$script:FrameCols = 2
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

function Limit-Text {
  param([string]$Text, [int]$Max)
  if ($Text.Length -le $Max) { return $Text }
  return $Text.Substring(0, $Max - 3) + "..."
}

function Add-PlainRow {
  param($Rows, $Fades, $Row)
  $Rows.Add($Row)
  $Fades.Add(1.0)
}

function Get-FrameEdge {
  param([int]$Left, [int]$Right, [int]$W)
  $r = New-Row
  $r.Add(@(([string][char]$Left + ($script:Rule * $W) + [string][char]$Right), $script:Ink.Empty, $false))
  return ,$r
}

function Get-FramedRow {
  param($Row, [int]$W, [double]$Fade)
  $side = [string][char]$script:FrameSide
  $r = New-Row
  $r.Add(@($side, $script:Ink.Empty, $false))
  $left = $W
  foreach ($s in $Row) {
    $t = [string]$s[0]
    if ($left -le 0 -or $t.Length -eq 0) { continue }
    $c = $s.Clone()
    if ($t.Length -gt $left) { $c[0] = $t.Substring(0, $left) }
    if ($Fade -lt 1) { $c[1] = Get-FadedRgb $s[1] $Fade $script:Ink.Bg }
    $r.Add($c)
    $left -= $c[0].Length
  }
  $r.Add(@(((" " * $left) + $side), $script:Ink.Empty, $false))
  return ,$r
}

function Get-FramedRows {
  param($Rows, $Fades, [int]$W)
  $out = New-Object 'System.Collections.Generic.List[object]'
  $out.Add((Get-FrameEdge 0x256D 0x256E $W))
  for ($i = 1; $i -lt $Rows.Count; $i++) {
    $f = 1.0
    if ($null -ne $Fades -and $i -lt $Fades.Count) { $f = $Fades[$i] }
    $out.Add((Get-FramedRow $Rows[$i] $W $f))
  }
  $out.Add((Get-FrameEdge 0x2570 0x256F $W))
  return ,$out
}

function Add-MarkSeg {
  param($Row)
  if ($Row.Count -eq 0 -or $Row[0][0].Length -lt 4) { return }
  $first = $Row[0]
  $Row[0] = @(("  " + $script:Mark + " "), $script:Levels["5h"][0], $false)
  if ($first[0].Length -gt 4) { $Row.Insert(1, @($first[0].Substring(4), $first[1], $first[2])) }
}
