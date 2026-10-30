$script:PageSign = $null
$script:PageDrawn = $null
$script:PageFading = $false

function Get-RowsSign {
  param($Rows)
  $sb = New-Object Text.StringBuilder 2048
  foreach ($r in $Rows) {
    foreach ($s in $r) {
      $c = $s[1]
      [void]$sb.Append($s[0]).Append([char]1).Append($c[0]).Append(",").Append($c[1]).Append(",").Append($c[2]).Append([char]1).Append([int][bool]$s[2]).Append([char]2)
    }
    [void]$sb.Append([char]3)
  }
  return $sb.ToString()
}

function Show-PageRows {
  param($Rows, [double]$Now, [bool]$Changed)
  $sign = Get-RowsSign $Rows
  $shown = [object]::ReferenceEquals($script:LastRows, $script:PageDrawn) -and $null -ne $script:PageDrawn
  $fading = Test-UiAnimating $Now
  if (-not $Changed -and $shown -and $sign -ceq $script:PageSign -and -not $fading -and -not $script:PageFading) { return }
  Show-UiRows $Rows $Now
  $script:PageFading = $fading
  $script:PageSign = $sign
  $script:PageDrawn = $Rows
}
