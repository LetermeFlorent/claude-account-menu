$script:NarrowOnly = New-Object System.Text.RegularExpressions.Regex('^[\x20-\x7E\u00A0-\u00AC\u00AE-\u02FF\u2010-\u2027\u2030-\u205F\u2190-\u22FF\u2500-\u25FC]*\z', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:ZeroWidthKinds = @([Globalization.UnicodeCategory]::NonSpacingMark, [Globalization.UnicodeCategory]::EnclosingMark, [Globalization.UnicodeCategory]::Format, [Globalization.UnicodeCategory]::Control)
$script:WideRanges = [int[]]@(
  0x1100, 0x115F, 0x2E80, 0x303E, 0x3041, 0x33FF, 0x3400, 0x4DBF, 0x4E00, 0x9FFF, 0xA000, 0xA4CF,
  0xAC00, 0xD7A3, 0xF900, 0xFAFF, 0xFE30, 0xFE4F, 0xFF00, 0xFF60, 0xFFE0, 0xFFE6,
  0x20000, 0x2FFFD, 0x30000, 0x3FFFD,
  0x1F300, 0x1F64F, 0x1F680, 0x1F6FF, 0x1F900, 0x1F9FF, 0x1FA70, 0x1FAFF, 0x1F200, 0x1F2FF,
  0x231A, 0x231B, 0x23E9, 0x23EC, 0x23F0, 0x23F0, 0x23F3, 0x23F3, 0x25FD, 0x25FE,
  0x2614, 0x2615, 0x2648, 0x2653, 0x267F, 0x267F, 0x2693, 0x2693, 0x26A1, 0x26A1,
  0x26AA, 0x26AB, 0x26BD, 0x26BE, 0x26C4, 0x26C5, 0x26CE, 0x26CE, 0x26D4, 0x26D4,
  0x26EA, 0x26EA, 0x26F2, 0x26F3, 0x26F5, 0x26F5, 0x26FA, 0x26FA, 0x26FD, 0x26FD,
  0x2705, 0x2705, 0x270A, 0x270B, 0x2728, 0x2728, 0x274C, 0x274C, 0x274E, 0x274E,
  0x2753, 0x2755, 0x2757, 0x2757, 0x2795, 0x2797, 0x27B0, 0x27B0, 0x27BF, 0x27BF,
  0x2B1B, 0x2B1C, 0x2B50, 0x2B50, 0x2B55, 0x2B55
)

function Get-CellWidth {
  param([string]$Text, [int]$Index, [int]$Step)
  $code = if ($Step -eq 2) { [char]::ConvertToUtf32($Text, $Index) } else { [int]$Text[$Index] }
  if ($script:ZeroWidthKinds -contains [Globalization.CharUnicodeInfo]::GetUnicodeCategory($Text, $Index)) { return 0 }
  if ($code -ge 0x1160 -and $code -le 0x11FF) { return 0 }
  $r = $script:WideRanges
  for ($k = 0; $k -lt $r.Length; $k += 2) {
    if ($code -ge $r[$k] -and $code -le $r[$k + 1]) { return 2 }
  }
  return 1
}

function Get-StepAt {
  param([string]$Text, [int]$Index)
  if ([char]::IsHighSurrogate($Text, $Index) -and $Index + 1 -lt $Text.Length -and [char]::IsLowSurrogate($Text, $Index + 1)) { return 2 }
  return 1
}

function Get-DisplayWidth {
  param([string]$Text)
  if ($script:NarrowOnly.IsMatch($Text)) { return $Text.Length }
  $total = 0
  $i = 0
  while ($i -lt $Text.Length) {
    $step = Get-StepAt $Text $i
    $total += Get-CellWidth $Text $i $step
    $i += $step
  }
  return [int]$total
}

function Limit-DisplayText {
  param([string]$Text, [int]$Max)
  if ($Max -le 0) { return "" }
  if ($script:NarrowOnly.IsMatch($Text)) {
    if ($Text.Length -le $Max) { return $Text }
    return $Text.Substring(0, $Max)
  }
  $used = 0
  $i = 0
  while ($i -lt $Text.Length) {
    $step = Get-StepAt $Text $i
    $used += Get-CellWidth $Text $i $step
    if ($used -gt $Max) { break }
    $i += $step
  }
  return $Text.Substring(0, $i)
}
