. Import-ClmModule claude-json
$script:ExcludeRegexMemo = New-PathMap
$script:RootsRegexMemo = New-PathMap
$script:ExcludeRegexOptions = [Text.RegularExpressions.RegexOptions]"IgnoreCase, CultureInvariant, Singleline"
$script:SafeSyncRoot = New-Object regex '^\.(?:claude(?:-[A-Za-z0-9_-]+)?(?:/|\z)|(?:claude|mcp|claude-accounts)\.json\z)', ([Text.RegularExpressions.RegexOptions]"IgnoreCase, CultureInvariant")
$script:UnsafeSyncPath = New-Object regex '[\\:]|(?:^|/)(?:/|\z)|[. ](?:/|\z)|(?:^|/)(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.[^/]*)?(?:/|\z)', ([Text.RegularExpressions.RegexOptions]"IgnoreCase, CultureInvariant")

function ConvertTo-WildcardRegex {
  param([string]$Pattern, [string]$Star, [string]$One)
  $sb = New-Object Text.StringBuilder
  for ($i = 0; $i -lt $Pattern.Length; $i++) {
    $ch = [string]$Pattern[$i]
    $close = -1
    if ($ch -eq "[") { $close = $Pattern.IndexOf("]", $i + 1) }
    if ($ch -eq "``" -and $i + 1 -lt $Pattern.Length) { $i++; [void]$sb.Append([regex]::Escape([string]$Pattern[$i])) }
    elseif ($ch -eq "*") { [void]$sb.Append($Star) }
    elseif ($ch -eq "?") { [void]$sb.Append($One) }
    elseif ($close -gt $i + 1) { [void]$sb.Append("[" + $Pattern.Substring($i + 1, $close - $i - 1).Replace("\", "\\").Replace("[", "\[").Replace("^", "\^") + "]"); $i = $close }
    else { [void]$sb.Append([regex]::Escape($ch)) }
  }
  return $sb.ToString()
}

function Get-ExcludeRegex {
  param($Patterns)
  $key = @($Patterns) -join "`n"
  if ($script:ExcludeRegexMemo.ContainsKey($key)) { return $script:ExcludeRegexMemo[$key] }
  $segments = New-Object 'System.Collections.Generic.List[string]'
  $paths = New-Object 'System.Collections.Generic.List[string]'
  foreach ($p in @($Patterns)) {
    if ($p.Contains("/")) { $paths.Add((ConvertTo-WildcardRegex $p ".*" ".")) }
    else { $segments.Add((ConvertTo-WildcardRegex $p "[^/]*" "[^/]")) }
  }
  $parts = @()
  if ($segments.Count -gt 0) { $parts += "(?:^|/)(?:" + ($segments -join "|") + ")(?:/|$)" }
  if ($paths.Count -gt 0) { $parts += "^(?:" + ($paths -join "|") + ")(?:/.*)?$" }
  if ($parts.Count -eq 0) { $parts = @("(?!)") }
  $rx = New-Object regex ($parts -join "|"), $script:ExcludeRegexOptions
  $script:ExcludeRegexMemo[$key] = $rx
  return $rx
}

function Get-RootsRegex {
  param($Roots)
  $key = @($Roots) -join "`n"
  if ($script:RootsRegexMemo.ContainsKey($key)) { return $script:RootsRegexMemo[$key] }
  $alts = @(foreach ($r in @($Roots)) { if ($r) { [regex]::Escape([string]$r) } })
  $text = "(?!)"
  if ($alts.Count -gt 0) { $text = "^(?:" + ($alts -join "|") + ")(?:/|\z)" }
  $rx = New-Object regex $text, ([Text.RegularExpressions.RegexOptions]::CultureInvariant)
  $script:RootsRegexMemo[$key] = $rx
  return $rx
}

function Test-SafeSyncPath {
  param([string]$Rel)
  return $script:SafeSyncRoot.IsMatch($Rel) -and -not $script:UnsafeSyncPath.IsMatch($Rel)
}
