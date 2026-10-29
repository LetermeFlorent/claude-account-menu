. Import-ClmModule claude-text

function Get-MenuFailText {
  param([string]$Name, [string]$Detail)
  switch ($Name) {
    "save" { return "  " + (Get-ClmText "menu.loop.fail.save" @($Detail)) }
    "restore" { return "  " + (Get-ClmText "menu.loop.fail.restore" @($Detail)) }
    "add" { return "  " + (Get-ClmText "menu.loop.fail.add" @($Detail)) }
    "remove" { return "  " + (Get-ClmText "menu.loop.fail.remove" @($Detail)) }
    "rename" { return "  " + (Get-ClmText "menu.loop.fail.rename" @($Detail)) }
    "drivelogin" { return "  " + (Get-ClmText "menu.loop.fail.drive.login" @($Detail)) }
    "prefs" { return "  " + (Get-ClmText "menu.loop.fail.prefs" @($Detail)) }
  }
  return "  " + $Detail
}
