Describe "Get-StateTag" {
  BeforeAll {
    . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "bin") "claude-platform.ps1")
  }

  It "donne le tag de chaque dossier de compte" {
    $cases = @(
      @{ Dir = "/home/u/.claude"; Tag = "claude" },
      @{ Dir = "C:\Users\u\.claude-compte2"; Tag = "claude-compte2" },
      @{ Dir = "/home/u/.Claude Work/"; Tag = "claude_work" }
    )
    foreach ($c in $cases) {
      $got = Get-StateTag $c.Dir
      if ($got -cne $c.Tag) { throw ($c.Dir + " : attendu " + $c.Tag + ", obtenu " + $got) }
    }
  }

  It "retombe sur claude quand le nom est vide" {
    foreach ($d in @("", "/home/u/...", "/")) {
      $got = Get-StateTag $d
      if ($got -cne "claude") { throw ("[" + $d + "] : attendu claude, obtenu " + $got) }
    }
  }
}
