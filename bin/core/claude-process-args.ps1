function ConvertTo-ProcessArgument {
  param([string]$Text)
  if ($Text.Length -gt 0 -and $Text -notmatch '[\s"]') { return $Text }
  $inner = [regex]::Replace($Text, '(\\*)"', { param($m) $m.Groups[1].Value + $m.Groups[1].Value + '\"' })
  $inner = [regex]::Replace($inner, '(\\+)\z', { param($m) $m.Groups[1].Value + $m.Groups[1].Value })
  return '"' + $inner + '"'
}

function ConvertTo-ProcessCommandLine {
  param([string[]]$Argv)
  return (@($Argv | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " ")
}
