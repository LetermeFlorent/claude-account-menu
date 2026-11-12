$script:CliCommands = @("--help", "-h", "--version", "--list", "--backups", "--update", "--drive-status", "--prefs")
$script:CliQuick = @("help", "version", "list")

function Get-CliCommand {
  param([object[]]$ArgList)
  $list = [string[]]@($ArgList | ForEach-Object { [string]$_ })
  if (@($list | Where-Object { $_ -match "^-[1-9]$" }).Count -gt 0) { return $null }
  for ($i = 0; $i -lt $list.Count; $i++) {
    if ($script:CliCommands -notcontains $list[$i]) { continue }
    $rest = @($list | Select-Object -Skip ($i + 1))
    $name = $list[$i].TrimStart("-")
    if ($name -eq "h") { $name = "help" }
    return @{ Name = $name; Values = [string[]]@($rest | Where-Object { -not $_.StartsWith("--") }) }
  }
  return $null
}

function Test-CliQuick {
  param([object[]]$ArgList)
  $cmd = Get-CliCommand $ArgList
  return $null -ne $cmd -and $script:CliQuick -contains $cmd.Name
}
