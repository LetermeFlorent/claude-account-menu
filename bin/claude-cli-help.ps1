. Import-ClmModule claude-text
$script:CliHelpSections = @("cli.help.intro", "cli.help.launch", "cli.help.accounts", "cli.help.updates", "cli.help.drive", "cli.help.prefs", "cli.help.display", "cli.help.variables", "cli.help.files", "cli.help.homeFiles")

function Get-CliKeyLines {
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $lines.Add((Get-ClmText "cli.help.menuKeys"))
  for ($i = 0; $i + 1 -lt $script:MenuFooter.Count; $i += 2) { $lines.Add("  " + $script:MenuFooter[$i].PadRight(8) + $script:MenuFooter[$i + 1]) }
  $lines.Add("  " + "u".PadRight(8) + (Get-ClmText "cli.help.menuInstall"))
  return ,$lines.ToArray()
}

function Get-CliHelpLines {
  $text = (@($script:CliHelpSections | ForEach-Object { Get-ClmText $_ }) -join "`n`n")
  $lines = @($text -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
  return ,[string[]]@($lines + "" + (Get-CliKeyLines))
}
