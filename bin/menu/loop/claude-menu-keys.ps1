$script:MenuKeys = @{ "m" = "refresh"; "u" = "selfupdate"; "y" = "drivesync"; "w" = "web"; "q" = "quit" }

$script:EntryActions = @("up", "down", "launch", "pick", "refresh")

function Limit-MenuAction {
  param($Action, [int]$Count)
  if ($Count -eq 0 -and $script:EntryActions -contains $Action.Name) { return @{ Name = "none" } }
  return $Action
}

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
