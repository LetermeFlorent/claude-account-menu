$script:MenuKeys = @{ "s" = "save"; "r" = "restore"; "a" = "add"; "x" = "remove"; "n" = "rename"; "q" = "quit" }

function Get-MenuAction {
  param($Key, [int]$Count)
  if ([int]$Key.KeyChar -eq 3) { return @{ Name = "quit" } }
  switch ($Key.Key) {
    "UpArrow" { return @{ Name = "up" } }
    "DownArrow" { return @{ Name = "down" } }
    "Enter" { return @{ Name = "launch" } }
    "Escape" { return @{ Name = "quit" } }
  }
  $c = ([string]$Key.KeyChar).ToLowerInvariant()
  if ($c -match "^[1-9]$") {
    if ([int]$c -le $Count) { return @{ Name = "pick"; Index = [int]$c - 1 } }
    return @{ Name = "none" }
  }
  if ($script:MenuKeys.ContainsKey($c)) { return @{ Name = $script:MenuKeys[$c] } }
  return @{ Name = "none" }
}
